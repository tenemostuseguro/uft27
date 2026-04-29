<?php
session_start();

function env_or_empty(string $key): string {
    $v = getenv($key);
    return $v === false ? '' : trim($v);
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

function api_request(string $method, string $url, string $serviceRoleKey, ?array $body = null): array {
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_CUSTOMREQUEST, $method);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'apikey: ' . $serviceRoleKey,
        'Authorization: Bearer ' . $serviceRoleKey,
        'Content-Type: application/json',
    ]);
    if ($body !== null) {
        curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($body));
    }
    $response = curl_exec($ch);
    $error = curl_error($ch);
    $status = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    if ($response === false) {
        return ['ok' => false, 'error' => 'cURL: ' . $error, 'status' => 0, 'data' => null];
    }
    $decoded = json_decode($response, true);
    if ($status < 200 || $status >= 300) {
        return ['ok' => false, 'error' => is_array($decoded) ? (string)($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded)) : $response, 'status' => $status, 'data' => $decoded];
    }
    return ['ok' => true, 'error' => '', 'status' => $status, 'data' => $decoded];
}

if (!isset($_SESSION['is_admin']) || $_SESSION['is_admin'] !== true) {
    header('Location: admin.php');
    exit;
}
if (!isset($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

$supabaseUrl = rtrim(env_or_empty('SUPABASE_URL'), '/');
$serviceRoleKey = env_or_empty('SUPABASE_SERVICE_ROLE_KEY');
$errors = [];
$success = '';
$openResult = null;
$selectedPlayerId = trim((string)($_GET['player_id'] ?? ''));

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token'])) {
    if (!hash_equals($_SESSION['csrf_token'], (string)$_POST['csrf_token'])) {
        $errors[] = 'CSRF token inválido.';
    } else {
        $action = (string)($_POST['action'] ?? '');
        if ($action === 'open_pack') {
            $selectedPlayerId = trim((string)($_POST['player_id'] ?? ''));
            $packId = trim((string)($_POST['pack_id'] ?? ''));
            if ($selectedPlayerId === '' || $packId === '') {
                $errors[] = 'player_id y pack_id son obligatorios.';
            } else {
                $resp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/open_uft_pack', $serviceRoleKey, [
                    'p_player_id' => $selectedPlayerId,
                    'p_pack_id' => $packId,
                ]);
                if ($resp['ok']) {
                    $openResult = $resp['data'];
                    $success = 'Sobre abierto correctamente.';
                } else {
                    $errors[] = 'Error al abrir sobre: ' . $resp['error'];
                }
            }
        }
    }
}

$packs = [];
$players = [];
$inventory = [];
if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $packsResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_packs', $serviceRoleKey, []);
    if ($packsResp['ok'] && is_array($packsResp['data'])) {
        $packs = $packsResp['data'];
    }
    $playersResp = api_request('GET', $supabaseUrl . '/rest/v1/player_accounts?select=id,username&order=created_at.desc&limit=200', $serviceRoleKey);
    if ($playersResp['ok'] && is_array($playersResp['data'])) {
        $players = $playersResp['data'];
    }
    if ($selectedPlayerId !== '') {
        $invResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_player_uft_cards', $serviceRoleKey, [
            'p_player_id' => $selectedPlayerId,
        ]);
        if ($invResp['ok'] && is_array($invResp['data'])) {
            $inventory = $invResp['data'];
        }
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Sistema de sobres UFT</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body{font-family:Inter,Arial,sans-serif;background:#020617;color:#e2e8f0;margin:0;padding:20px}
        .panel{background:#0f172a;border:1px solid #1e293b;border-radius:12px;padding:16px;margin-bottom:14px}
        .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px}
        select,input,button{padding:10px;border-radius:8px;border:1px solid #334155;background:#020617;color:#e2e8f0}
        button{cursor:pointer;background:#2563eb;border:none;color:#fff;font-weight:600}
        table{width:100%;border-collapse:collapse}
        th,td{padding:8px;border-bottom:1px solid #1e293b;text-align:left}
        .ok{border-color:#22c55e}.err{border-color:#ef4444}
        code{background:#111827;padding:2px 6px;border-radius:6px}
    </style>
</head>
<body>
<h1>Sistema de sobres UFT</h1>
<p><a href="admin.php" style="color:#93c5fd;">← Volver al panel principal</a></p>

<?php foreach ($errors as $e): ?><div class="panel err"><?php echo h($e); ?></div><?php endforeach; ?>
<?php if ($success !== ''): ?><div class="panel ok"><?php echo h($success); ?></div><?php endif; ?>

<div class="panel">
    <h2 style="margin-top:0;">Abrir sobre para un jugador</h2>
    <form method="post" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="open_pack">
        <div>
            <label>Jugador</label>
            <select name="player_id" required>
                <option value="">Selecciona usuario</option>
                <?php foreach ($players as $player): ?>
                    <?php $id = (string)($player['id'] ?? ''); ?>
                    <option value="<?php echo h($id); ?>" <?php echo $selectedPlayerId === $id ? 'selected' : ''; ?>>
                        <?php echo h((string)($player['username'] ?? 'sin_username')); ?> · <?php echo h($id); ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
        <div>
            <label>Sobre</label>
            <select name="pack_id" required>
                <option value="">Selecciona sobre</option>
                <?php foreach ($packs as $pack): ?>
                    <option value="<?php echo h((string)($pack['pack_id'] ?? '')); ?>">
                        <?php echo h((string)($pack['name'] ?? '')); ?> · <?php echo h((string)($pack['pack_id'] ?? '')); ?>
                    </option>
                <?php endforeach; ?>
            </select>
        </div>
        <div style="align-self:end"><button type="submit">Abrir sobre</button></div>
    </form>
</div>

<?php if (is_array($openResult)): ?>
<div class="panel">
    <h3 style="margin-top:0;">Resultado última apertura</h3>
    <p><strong>Won cards:</strong> <code><?php echo h(json_encode($openResult['won_cards'] ?? [])); ?></code></p>
    <p><strong>Duplicados:</strong> <?php echo h((string)($openResult['duplicates'] ?? 0)); ?></p>
    <p><strong>Coins por duplicado:</strong> <?php echo h((string)($openResult['duplicate_coins'] ?? 0)); ?></p>
</div>
<?php endif; ?>

<div class="panel">
    <h3 style="margin-top:0;">Inventario del jugador seleccionado</h3>
    <table>
        <thead><tr><th>card_id</th><th>cantidad</th><th>updated_at</th></tr></thead>
        <tbody>
        <?php if (count($inventory) === 0): ?>
            <tr><td colspan="3">Sin cartas registradas todavía.</td></tr>
        <?php endif; ?>
        <?php foreach ($inventory as $row): ?>
            <tr>
                <td><code><?php echo h((string)($row['card_id'] ?? '')); ?></code></td>
                <td><?php echo h((string)($row['quantity'] ?? '0')); ?></td>
                <td><?php echo h((string)($row['updated_at'] ?? '')); ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
</body>
</html>
