<?php
session_start();

function env_or_empty(string $key): string {
    $value = getenv($key);
    return $value === false ? '' : trim($value);
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

function hash_password(string $password): string {
    return hash('sha256', $password);
}

function api_request(string $method, string $url, string $serviceRoleKey, ?array $body = null): array {
    $ch = curl_init($url);
    $headers = [
        'apikey: ' . $serviceRoleKey,
        'Authorization: Bearer ' . $serviceRoleKey,
        'Content-Type: application/json',
    ];

    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, $headers);

    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }

    $response = curl_exec($ch);
    $curlError = curl_error($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response === false) {
        return ['ok' => false, 'status' => 0, 'error' => 'cURL error: ' . $curlError, 'data' => null];
    }

    $decoded = json_decode($response, true);

    if ($status < 200 || $status >= 300) {
        $error = is_array($decoded)
            ? (string) ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded))
            : $response;
        return ['ok' => false, 'status' => $status, 'error' => $error, 'data' => $decoded];
    }

    return ['ok' => true, 'status' => $status, 'error' => '', 'data' => $decoded];
}

$supabaseUrl = rtrim(env_or_empty('SUPABASE_URL'), '/');
$serviceRoleKey = env_or_empty('SUPABASE_SERVICE_ROLE_KEY');
$adminPassword = env_or_empty('ADMIN_PANEL_PASSWORD');

$errors = [];
$success = '';

if ($adminPassword === '') {
    $errors[] = 'Falta ADMIN_PANEL_PASSWORD en variables de entorno.';
}
if ($supabaseUrl === '') {
    $errors[] = 'Falta SUPABASE_URL en variables de entorno.';
}
if ($serviceRoleKey === '') {
    $errors[] = 'Falta SUPABASE_SERVICE_ROLE_KEY en variables de entorno.';
}

if (!isset($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

if (isset($_POST['logout'])) {
    $_SESSION = [];
    session_destroy();
    header('Location: ' . $_SERVER['PHP_SELF']);
    exit;
}

if (!isset($_SESSION['is_admin']) || $_SESSION['is_admin'] !== true) {
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['login_password'])) {
        $passwordInput = (string) $_POST['login_password'];
        if ($adminPassword !== '' && hash_equals($adminPassword, $passwordInput)) {
            $_SESSION['is_admin'] = true;
            header('Location: ' . $_SERVER['PHP_SELF']);
            exit;
        }
        $errors[] = 'Contraseña de admin inválida.';
    }

    ?>
    <!doctype html>
    <html lang="es">
    <head>
        <meta charset="utf-8">
        <title>Admin UFT27 - Login</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {font-family: Arial, sans-serif; background:#0f172a; color:#e2e8f0; display:flex; justify-content:center; align-items:center; min-height:100vh; margin:0;}
            .card {background:#111827; width:100%; max-width:420px; border-radius:12px; padding:24px; box-shadow:0 12px 30px rgba(0,0,0,.35);} 
            input, button {width:100%; padding:12px; border-radius:8px; border:1px solid #334155; margin-top:10px; box-sizing:border-box;}
            input {background:#0b1220; color:#e2e8f0;}
            button {background:#2563eb; color:#fff; border:none; cursor:pointer;}
            .error {background:#7f1d1d; border:1px solid #ef4444; padding:10px; border-radius:8px; margin-top:10px;}
        </style>
    </head>
    <body>
        <div class="card">
            <h1>UFT 27 - Admin</h1>
            <p>Ingresá la contraseña de administración.</p>
            <?php foreach ($errors as $error): ?>
                <div class="error"><?php echo h($error); ?></div>
            <?php endforeach; ?>
            <form method="post">
                <label for="login_password">Contraseña admin</label>
                <input type="password" id="login_password" name="login_password" required>
                <button type="submit">Entrar</button>
            </form>
        </div>
    </body>
    </html>
    <?php
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token'])) {
    if (!hash_equals($_SESSION['csrf_token'], (string) $_POST['csrf_token'])) {
        $errors[] = 'CSRF token inválido.';
    } else {
        $action = (string) ($_POST['action'] ?? '');
        $userId = (string) ($_POST['user_id'] ?? '');

        if ($action === 'delete' && $userId !== '') {
            $url = $supabaseUrl . '/rest/v1/player_accounts?id=eq.' . rawurlencode($userId);
            $result = api_request('DELETE', $url, $serviceRoleKey);
            if ($result['ok']) {
                $success = 'Usuario eliminado correctamente.';
            } else {
                $errors[] = 'No se pudo eliminar usuario: ' . $result['error'];
            }
        }

        if ($action === 'reset_password' && $userId !== '') {
            $newPassword = (string) ($_POST['new_password'] ?? '');
            if (strlen($newPassword) < 6) {
                $errors[] = 'La nueva contraseña debe tener al menos 6 caracteres.';
            } else {
                $url = $supabaseUrl . '/rest/v1/player_accounts?id=eq.' . rawurlencode($userId);
                $payload = [
                    'password_hash' => hash_password($newPassword),
                    'updated_at' => gmdate('Y-m-d\\TH:i:s\\Z'),
                ];
                $result = api_request('PATCH', $url, $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $success = 'Contraseña actualizada correctamente.';
                } else {
                    $errors[] = 'No se pudo actualizar contraseña: ' . $result['error'];
                }
            }
        }

        if ($action === 'create_notification') {
            $header = trim((string) ($_POST['header'] ?? 'MENSAJE DEL EQUIPO UFT'));
            $title = trim((string) ($_POST['title'] ?? ''));
            $body = trim((string) ($_POST['body'] ?? ''));
            $imageUrl = trim((string) ($_POST['image_url'] ?? ''));

            if ($title === '' || $body === '') {
                $errors[] = 'Título y contenido son obligatorios para la notificación.';
            } else {
                $url = $supabaseUrl . '/rest/v1/notifications';
                $payload = [
                    'header' => $header === '' ? 'MENSAJE DEL EQUIPO UFT' : $header,
                    'title' => $title,
                    'body' => $body,
                    'image_url' => $imageUrl,
                    'active' => true,
                ];
                $result = api_request('POST', $url, $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $success = 'Notificación creada correctamente.';
                } else {
                    $errors[] = 'No se pudo crear notificación: ' . $result['error'];
                }
            }
        }

        if ($action === 'create_logo') {
            $name = trim((string) ($_POST['logo_name'] ?? ''));
            $imageUrl = trim((string) ($_POST['logo_image_url'] ?? ''));
            $sourceType = trim((string) ($_POST['logo_source_type'] ?? 'event'));

            if ($name === '' || $imageUrl === '') {
                $errors[] = 'Nombre e imagen del logo son obligatorios.';
            } else {
                $url = $supabaseUrl . '/rest/v1/profile_logos';
                $payload = [
                    'name' => $name,
                    'image_url' => $imageUrl,
                    'source_type' => $sourceType,
                    'active' => true,
                ];
                $result = api_request('POST', $url, $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $success = 'Logo de perfil creado correctamente.';
                } else {
                    $errors[] = 'No se pudo crear logo de perfil: ' . $result['error'];
                }
            }
        }

        if ($action === 'assign_user_logo') {
            $targetUserId = trim((string) ($_POST['target_user_id'] ?? ''));
            $targetLogoId = trim((string) ($_POST['target_logo_id'] ?? ''));
            $customLogoUrl = trim((string) ($_POST['target_custom_logo_url'] ?? ''));
            if ($targetUserId === '') {
                $errors[] = 'Usuario inválido para asignación de logo.';
            } else {
                $rpcUrl = $supabaseUrl . '/rest/v1/rpc/set_player_profile_logo';
                $payload = [
                    'p_player_id' => $targetUserId,
                    'p_logo_id' => ($targetLogoId === '' ? null : $targetLogoId),
                    'p_custom_image_url' => $customLogoUrl,
                ];
                $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $success = 'Logo asignado al perfil correctamente.';
                } else {
                    $errors[] = 'No se pudo asignar logo al perfil: ' . $result['error'];
                }
            }
        }
    }
}

$users = [];
$notifications = [];
$profileLogos = [];
if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $url = $supabaseUrl . '/rest/v1/player_accounts?select=id,username,created_at,updated_at&order=created_at.desc';
    $result = api_request('GET', $url, $serviceRoleKey);
    if ($result['ok'] && is_array($result['data'])) {
        $users = $result['data'];
    } elseif (!$result['ok']) {
        $errors[] = 'No se pudo cargar lista de usuarios: ' . $result['error'];
    }

    $notificationsUrl = $supabaseUrl . '/rest/v1/notifications?select=id,header,title,image_url,active,created_at&order=created_at.desc';
    $notificationsResult = api_request('GET', $notificationsUrl, $serviceRoleKey);
    if ($notificationsResult['ok'] && is_array($notificationsResult['data'])) {
        $notifications = $notificationsResult['data'];
    } elseif (!$notificationsResult['ok']) {
        $errors[] = 'No se pudo cargar lista de notificaciones: ' . $notificationsResult['error'];
    }

    $logosUrl = $supabaseUrl . '/rest/v1/profile_logos?select=id,name,image_url,source_type,is_default,active,created_at&order=created_at.desc';
    $logosResult = api_request('GET', $logosUrl, $serviceRoleKey);
    if ($logosResult['ok'] && is_array($logosResult['data'])) {
        $profileLogos = $logosResult['data'];
    } elseif (!$logosResult['ok']) {
        $errors[] = 'No se pudo cargar lista de logos de perfil: ' . $logosResult['error'];
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Admin UFT27</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {font-family: Arial, sans-serif; background:#020617; color:#e2e8f0; margin:0; padding:24px;}
        .top {display:flex; justify-content:space-between; align-items:center; gap:12px; flex-wrap:wrap;}
        .panel {background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:16px; margin-top:16px;}
        table {width:100%; border-collapse: collapse; margin-top:12px;}
        th, td {padding:10px; border-bottom:1px solid #1e293b; text-align:left; vertical-align:top;}
        th {background:#111827;}
        .error {background:#7f1d1d; border:1px solid #ef4444; padding:10px; border-radius:8px; margin-top:10px;}
        .success {background:#14532d; border:1px solid #22c55e; padding:10px; border-radius:8px; margin-top:10px;}
        input[type="password"], input[type="text"], textarea, select {padding:8px; border-radius:8px; border:1px solid #334155; background:#0b1220; color:#e2e8f0;}
input[type="password"] {width:180px;}
textarea {width:100%; box-sizing:border-box;}
        .btn {padding:8px 12px; border-radius:8px; border:none; cursor:pointer; color:#fff;}
        .btn-primary {background:#2563eb;}
        .btn-danger {background:#dc2626;}
        .btn-secondary {background:#475569;}
        form.inline {display:inline-flex; gap:8px; align-items:center; flex-wrap:wrap;}
        code {background:#111827; padding:2px 6px; border-radius:6px;}
    </style>
</head>
<body>
    <div class="top">
        <div>
            <h1 style="margin:0;">UFT 27 - Panel Admin</h1>
            <p style="margin:6px 0 0 0; color:#94a3b8;">Moderación de cuentas <code>player_accounts</code> en Supabase.</p>
        </div>
        <form method="post" class="inline">
            <button class="btn btn-secondary" name="logout" value="1" type="submit">Cerrar sesión</button>
        </form>
    </div>

    <?php foreach ($errors as $error): ?>
        <div class="error"><?php echo h($error); ?></div>
    <?php endforeach; ?>
    <?php if ($success !== ''): ?>
        <div class="success"><?php echo h($success); ?></div>
    <?php endif; ?>

    <div class="panel">
        <strong>Total usuarios:</strong> <?php echo count($users); ?>
        <table>
            <thead>
                <tr>
                    <th>Username</th>
                    <th>ID</th>
                    <th>Creado</th>
                    <th>Actualizado</th>
                    <th>Acciones</th>
                </tr>
            </thead>
            <tbody>
                <?php if (count($users) === 0): ?>
                    <tr><td colspan="5">Sin usuarios para mostrar.</td></tr>
                <?php endif; ?>
                <?php foreach ($users as $user): ?>
                    <tr>
                        <td><?php echo h((string) ($user['username'] ?? '')); ?></td>
                        <td><code><?php echo h((string) ($user['id'] ?? '')); ?></code></td>
                        <td><?php echo h((string) ($user['created_at'] ?? '')); ?></td>
                        <td><?php echo h((string) ($user['updated_at'] ?? '')); ?></td>
                        <td>
                            <form method="post" class="inline" onsubmit="return confirm('¿Eliminar usuario? Esta acción no se puede deshacer.');">
                                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="user_id" value="<?php echo h((string) ($user['id'] ?? '')); ?>">
                                <button class="btn btn-danger" type="submit">Eliminar</button>
                            </form>
                            <form method="post" class="inline">
                                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                                <input type="hidden" name="action" value="reset_password">
                                <input type="hidden" name="user_id" value="<?php echo h((string) ($user['id'] ?? '')); ?>">
                                <input type="password" name="new_password" minlength="6" placeholder="Nueva contraseña" required>
                                <button class="btn btn-primary" type="submit">Reset pass</button>
                            </form>
                        </td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>


    <div class="panel">
        <h2 style="margin-top:0;">Logos de perfil (eventos/equipos)</h2>
        <p style="color:#94a3b8; margin-top:0;">Crea logos desbloqueables (evento/equipo) y asígnalos a usuarios.</p>
        <form method="post" style="display:grid; gap:10px; max-width:900px; margin-bottom:14px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="create_logo">
            <input type="text" name="logo_name" placeholder="Nombre del logo" required>
            <input type="text" name="logo_image_url" placeholder="URL o ruta del logo (.png o .gif)" required>
            <select name="logo_source_type">
                <option value="event">Evento</option>
                <option value="team">Equipo</option>
                <option value="default">Default</option>
            </select>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Crear logo</button>
        </form>

        <form method="post" style="display:grid; gap:10px; max-width:900px; margin-bottom:14px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="assign_user_logo">
            <input type="text" name="target_user_id" placeholder="UUID del usuario" required>
            <select name="target_logo_id">
                <option value="">(Usar default)</option>
                <?php foreach ($profileLogos as $logo): ?>
                    <option value="<?php echo h((string) ($logo['id'] ?? '')); ?>"><?php echo h((string) ($logo['name'] ?? 'Logo')); ?> (<?php echo h((string) ($logo['source_type'] ?? 'event')); ?>)</option>
                <?php endforeach; ?>
            </select>
            <input type="text" name="target_custom_logo_url" placeholder="URL logo personalizada (opcional)">
            <button class="btn btn-secondary" type="submit" style="width:max-content;">Asignar logo a usuario</button>
        </form>

        <table>
            <thead>
                <tr><th>Nombre</th><th>Tipo</th><th>Default</th><th>Imagen</th><th>Creada</th></tr>
            </thead>
            <tbody>
                <?php if (count($profileLogos) === 0): ?>
                    <tr><td colspan="5">Sin logos de perfil.</td></tr>
                <?php endif; ?>
                <?php foreach ($profileLogos as $logo): ?>
                    <tr>
                        <td><?php echo h((string) ($logo['name'] ?? '')); ?></td>
                        <td><?php echo h((string) ($logo['source_type'] ?? '')); ?></td>
                        <td><?php echo ((bool) ($logo['is_default'] ?? false)) ? 'Sí' : 'No'; ?></td>
                        <td><code><?php echo h((string) ($logo['image_url'] ?? '')); ?></code></td>
                        <td><?php echo h((string) ($logo['created_at'] ?? '')); ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>

    <div class="panel">
        <h2 style="margin-top:0;">Notificaciones in-game</h2>
        <p style="color:#94a3b8; margin-top:0;">Creá eventos con imagen (URL pública o ruta accesible) para mostrarlos en el juego.</p>
        <form method="post" style="display:grid; gap:10px; max-width:900px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="create_notification">
            <input type="text" name="header" placeholder="Header (ej: MESSAGE FROM THE UFT TEAM)">
            <input type="text" name="title" placeholder="Título" required>
            <textarea name="body" rows="5" placeholder="Texto de la notificación" required></textarea>
            <input type="text" name="image_url" placeholder="URL de imagen (https://...) o ruta local del cliente">
            <button class="btn btn-primary" type="submit" style="width:max-content;">Publicar notificación</button>
        </form>

        <table>
            <thead>
                <tr>
                    <th>Título</th>
                    <th>Header</th>
                    <th>Imagen</th>
                    <th>Estado</th>
                    <th>Creada</th>
                </tr>
            </thead>
            <tbody>
                <?php if (count($notifications) === 0): ?>
                    <tr><td colspan="5">Sin notificaciones.</td></tr>
                <?php endif; ?>
                <?php foreach ($notifications as $notification): ?>
                    <tr>
                        <td><?php echo h((string) ($notification['title'] ?? '')); ?></td>
                        <td><?php echo h((string) ($notification['header'] ?? '')); ?></td>
                        <td><code><?php echo h((string) ($notification['image_url'] ?? '')); ?></code></td>
                        <td><?php echo ((bool) ($notification['active'] ?? false)) ? 'Activa' : 'Inactiva'; ?></td>
                        <td><?php echo h((string) ($notification['created_at'] ?? '')); ?></td>
                    </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</body>
</html>
