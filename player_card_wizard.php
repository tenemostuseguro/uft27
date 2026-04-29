<?php
session_start();

function env_or_empty(string $key): string {
    $value = getenv($key);
    return $value === false ? '' : trim($value);
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
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
$errors = [];
$success = '';

if (!isset($_SESSION['is_admin']) || $_SESSION['is_admin'] !== true) {
    header('Location: admin.php');
    exit;
}

if (!isset($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

$selectedPlayerId = trim((string) ($_GET['player_id'] ?? ''));

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token'])) {
    if (!hash_equals($_SESSION['csrf_token'], (string) $_POST['csrf_token'])) {
        $errors[] = 'CSRF token inválido.';
    } else {
        $action = (string) ($_POST['action'] ?? '');

        if ($action === 'wizard_create_player') {
            $payload = [
                'p_player_id' => trim((string) ($_POST['p_player_id'] ?? '')),
                'p_name' => trim((string) ($_POST['p_name'] ?? '')),
                'p_main_position' => trim((string) ($_POST['p_main_position'] ?? 'P')),
                'p_secondary_positions' => json_decode((string) ($_POST['p_secondary_positions'] ?? '[]'), true),
                'p_dominant_foot' => trim((string) ($_POST['p_dominant_foot'] ?? '')),
                'p_nationality' => trim((string) ($_POST['p_nationality'] ?? '')),
                'p_club_id' => (($clubId = trim((string) ($_POST['p_club_id'] ?? ''))) === '' ? null : $clubId),
                'p_photo_face_url' => trim((string) ($_POST['p_photo_face_url'] ?? '')),
                'p_metadata' => json_decode((string) ($_POST['p_metadata'] ?? '{}'), true),
            ];

            if ($payload['p_player_id'] === '' || $payload['p_name'] === '' || $payload['p_club_id'] === null) {
                $errors[] = 'Para crear jugador: player_id, nombre y club son obligatorios.';
            } else {
                $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_player', $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $selectedPlayerId = (string) $payload['p_player_id'];
                    $success = '✅ Jugador guardado. Paso 2: crea la carta.';
                } else {
                    $errors[] = 'No se pudo guardar jugador: ' . $result['error'];
                }
            }
        }

        if ($action === 'wizard_create_card') {
            $payload = [
                'p_card_id' => trim((string) ($_POST['p_card_id'] ?? '')),
                'p_player_id' => trim((string) ($_POST['p_player_id'] ?? '')),
                'p_card_type' => trim((string) ($_POST['p_card_type'] ?? 'Base')),
                'p_rarity' => trim((string) ($_POST['p_rarity'] ?? 'Common')),
                'p_ovr' => (int) ($_POST['p_ovr'] ?? 1),
                'p_pace' => (int) ($_POST['p_pace'] ?? 1),
                'p_dribbling' => (int) ($_POST['p_dribbling'] ?? 1),
                'p_passing' => (int) ($_POST['p_passing'] ?? 1),
                'p_shooting' => (int) ($_POST['p_shooting'] ?? 1),
                'p_defense' => (int) ($_POST['p_defense'] ?? 1),
                'p_physical' => (int) ($_POST['p_physical'] ?? 1),
                'p_gk_reflejos' => (int) ($_POST['p_gk_reflejos'] ?? 1),
                'p_gk_parada' => (int) ($_POST['p_gk_parada'] ?? 1),
                'p_gk_uno_vs_uno' => (int) ($_POST['p_gk_uno_vs_uno'] ?? 1),
                'p_gk_colocacion' => (int) ($_POST['p_gk_colocacion'] ?? 1),
                'p_gk_juego_pies' => (int) ($_POST['p_gk_juego_pies'] ?? 1),
                'p_gk_fisico' => (int) ($_POST['p_gk_fisico'] ?? 1),
                'p_evolution_level' => (int) ($_POST['p_evolution_level'] ?? 1),
                'p_card_frame_url' => trim((string) ($_POST['p_card_frame_url'] ?? '')),
                'p_face_url' => trim((string) ($_POST['p_face_url'] ?? '')),
                'p_owned' => isset($_POST['p_owned']),
                'p_transferable' => isset($_POST['p_transferable']),
                'p_locked' => isset($_POST['p_locked']),
                'p_suggested_price' => (int) ($_POST['p_suggested_price'] ?? 0),
            ];
            if ($payload['p_card_id'] === '' || $payload['p_player_id'] === '') {
                $errors[] = 'Para crear carta: card_id y player_id son obligatorios.';
            } else {
                $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_card', $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $selectedPlayerId = (string) $payload['p_player_id'];
                    $success = '✅ Carta guardada correctamente.';
                } else {
                    $errors[] = 'No se pudo guardar carta: ' . $result['error'];
                }
            }
        }
    }
}

$clubs = [];
$players = [];
$cardTypes = [];
if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $clubsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_clubs', $serviceRoleKey, []);
    if ($clubsResult['ok'] && is_array($clubsResult['data'])) {
        $clubs = $clubsResult['data'];
    }
    $playersResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_players', $serviceRoleKey, []);
    if ($playersResult['ok'] && is_array($playersResult['data'])) {
        $players = $playersResult['data'];
    }
    $typesResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_card_types', $serviceRoleKey, []);
    if ($typesResult['ok'] && is_array($typesResult['data'])) {
        $cardTypes = $typesResult['data'];
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Asistente UFT · Jugadores y Cartas</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {font-family: Inter, Arial, sans-serif; margin:0; padding:20px; background:#020617; color:#e2e8f0;}
        .panel {background:#0f172a; border:1px solid #1e293b; border-radius:14px; padding:16px; margin-top:16px;}
        .steps {display:grid; grid-template-columns:repeat(2,minmax(200px,1fr)); gap:12px;}
        .step {border:1px solid #334155; border-radius:10px; padding:12px; background:#0b1220;}
        .step.active {border-color:#38bdf8; box-shadow:0 0 0 1px #38bdf8 inset;}
        .grid {display:grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap:10px;}
        .field {display:grid; gap:6px;}
        input, select, textarea {padding:10px; border-radius:8px; border:1px solid #334155; background:#020617; color:#e2e8f0; width:100%; box-sizing:border-box;}
        .btn {padding:10px 14px; border:none; border-radius:8px; color:#fff; cursor:pointer; font-weight:600;}
        .primary {background:#2563eb;}
        .ok {border-color:#22c55e;}
        .error {border-color:#ef4444;}
        .hint {color:#94a3b8; font-size:.95rem; margin-top:0;}
        .inline {display:flex; gap:14px; align-items:center; flex-wrap:wrap;}
        table {width:100%; border-collapse:collapse; margin-top:10px;}
        th, td {padding:8px; border-bottom:1px solid #1e293b; text-align:left;}
        code {background:#111827; padding:2px 6px; border-radius:6px;}
    </style>
</head>
<body>
<h1>Asistente UFT: crear jugador + carta</h1>
<p class="hint">Flujo recomendado: 1) creas jugador ligado a un club por ID, 2) creas su carta.</p>
<p><a href="admin.php" style="color:#93c5fd;">← Volver al panel principal</a></p>

<?php foreach ($errors as $error): ?><div class="panel error"><?php echo h($error); ?></div><?php endforeach; ?>
<?php if ($success !== ''): ?><div class="panel ok"><?php echo h($success); ?></div><?php endif; ?>

<div class="steps">
    <div class="step active">
        <strong>Paso 1 · Jugador</strong>
        <p class="hint">Crear/actualizar jugador base. Club obligatorio por UUID.</p>
    </div>
    <div class="step <?php echo $selectedPlayerId !== '' ? 'active' : ''; ?>">
        <strong>Paso 2 · Carta</strong>
        <p class="hint">Crear carta vinculada al jugador recién creado.</p>
    </div>
</div>

<div class="panel">
    <h2 style="margin-top:0;">Paso 1: Jugador</h2>
    <form method="post" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="wizard_create_player">
        <div class="field"><label>player_id *</label><input type="text" name="p_player_id" placeholder="ej: p_messi_001" required></div>
        <div class="field"><label>Nombre *</label><input type="text" name="p_name" placeholder="Nombre del jugador" required></div>
        <div class="field"><label>Posición principal *</label><input type="text" name="p_main_position" value="P" required></div>
        <div class="field"><label>Posiciones secundarias (JSON)</label><input type="text" name="p_secondary_positions" value="[]"></div>
        <div class="field"><label>Pie dominante</label><input type="text" name="p_dominant_foot" placeholder="Derecho / Izquierdo"></div>
        <div class="field"><label>Nacionalidad</label><input type="text" name="p_nationality" placeholder="Argentina"></div>
        <div class="field">
            <label>Club (ID UUID) *</label>
            <select name="p_club_id" required>
                <option value="">Selecciona club</option>
                <?php foreach ($clubs as $club): ?>
                    <option value="<?php echo h((string) ($club['id'] ?? '')); ?>">
                        <?php echo h((string) ($club['name'] ?? 'Sin nombre')); ?> · <?php echo h((string) ($club['id'] ?? '')); ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="field"><label>URL foto</label><input type="text" name="p_photo_face_url" placeholder="https://..."></div>
        <div class="field" style="grid-column:1 / -1;"><label>Metadata JSON</label><textarea name="p_metadata" rows="3">{}</textarea></div>
        <div><button class="btn primary" type="submit">Guardar jugador y pasar al paso 2</button></div>
    </form>
</div>

<div class="panel">
    <h2 style="margin-top:0;">Paso 2: Carta</h2>
    <form method="post" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="wizard_create_card">
        <div class="field"><label>card_id *</label><input type="text" name="p_card_id" placeholder="ej: card_p_messi_001_base" required></div>
        <div class="field">
            <label>player_id *</label>
            <select name="p_player_id" required>
                <option value="">Selecciona jugador</option>
                <?php foreach ($players as $player): ?>
                    <?php $pid = (string) ($player['player_id'] ?? ''); ?>
                    <option value="<?php echo h($pid); ?>" <?php echo $selectedPlayerId === $pid ? 'selected' : ''; ?>>
                        <?php echo h($pid); ?> · <?php echo h((string) ($player['name'] ?? '')); ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="field">
            <label>Tipo de carta *</label>
            <select name="p_card_type" required>
                <?php foreach ($cardTypes as $type): ?>
                    <?php $typeId = (string) ($type['card_type'] ?? 'Base'); ?>
                    <option value="<?php echo h($typeId); ?>"><?php echo h($typeId); ?></option>
                <?php endforeach; ?>
            </select>
        </div>
        <div class="field"><label>Rareza *</label><input type="text" name="p_rarity" value="Common" required></div>
        <div class="field"><label>OVR *</label><input type="number" name="p_ovr" min="1" max="120" value="70" required></div>
        <div class="field"><label>Evolución</label><input type="number" name="p_evolution_level" min="1" value="1"></div>
        <div class="field"><label>Precio sugerido</label><input type="number" name="p_suggested_price" min="0" value="0"></div>
        <div class="field"><label>Card frame URL</label><input type="text" name="p_card_frame_url"></div>
        <div class="field"><label>Face URL</label><input type="text" name="p_face_url"></div>
        <div class="inline" style="grid-column:1 / -1;">
            <label><input type="checkbox" name="p_owned" checked> Poseída</label>
            <label><input type="checkbox" name="p_transferable" checked> Transferible</label>
            <label><input type="checkbox" name="p_locked"> Bloqueada</label>
        </div>
        <div class="grid" style="grid-column:1 / -1;">
            <div class="field"><label>Pace</label><input type="number" name="p_pace" min="1" max="120" value="60"></div>
            <div class="field"><label>Dribbling</label><input type="number" name="p_dribbling" min="1" max="120" value="60"></div>
            <div class="field"><label>Passing</label><input type="number" name="p_passing" min="1" max="120" value="60"></div>
            <div class="field"><label>Shooting</label><input type="number" name="p_shooting" min="1" max="120" value="60"></div>
            <div class="field"><label>Defense</label><input type="number" name="p_defense" min="1" max="120" value="60"></div>
            <div class="field"><label>Physical</label><input type="number" name="p_physical" min="1" max="120" value="60"></div>
        </div>
        <details style="grid-column:1 / -1;">
            <summary>Stats de portero (opcionales)</summary>
            <div class="grid" style="margin-top:10px;">
                <div class="field"><label>GK reflejos</label><input type="number" name="p_gk_reflejos" min="1" max="120" value="60"></div>
                <div class="field"><label>GK parada</label><input type="number" name="p_gk_parada" min="1" max="120" value="60"></div>
                <div class="field"><label>GK 1v1</label><input type="number" name="p_gk_uno_vs_uno" min="1" max="120" value="60"></div>
                <div class="field"><label>GK colocación</label><input type="number" name="p_gk_colocacion" min="1" max="120" value="60"></div>
                <div class="field"><label>GK juego pies</label><input type="number" name="p_gk_juego_pies" min="1" max="120" value="60"></div>
                <div class="field"><label>GK físico</label><input type="number" name="p_gk_fisico" min="1" max="120" value="60"></div>
            </div>
        </details>
        <div><button class="btn primary" type="submit">Guardar carta</button></div>
    </form>
</div>

<div class="panel">
    <h3 style="margin-top:0;">Últimos jugadores</h3>
    <table>
        <thead><tr><th>player_id</th><th>Nombre</th><th>club_id</th></tr></thead>
        <tbody>
        <?php foreach (array_slice($players, 0, 10) as $player): ?>
            <tr>
                <td><code><?php echo h((string) ($player['player_id'] ?? '')); ?></code></td>
                <td><?php echo h((string) ($player['name'] ?? '')); ?></td>
                <td><code><?php echo h((string) ($player['club_id'] ?? '')); ?></code></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
</body>
</html>
