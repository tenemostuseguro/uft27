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
        return ['ok' => false, 'status' => 0, 'error' => 'cURL: ' . $error, 'data' => null];
    }
    $decoded = json_decode($response, true);
    if ($status < 200 || $status >= 300) {
        return ['ok' => false, 'status' => $status, 'error' => is_array($decoded) ? (string)($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded)) : $response, 'data' => $decoded];
    }
    return ['ok' => true, 'status' => $status, 'error' => '', 'data' => $decoded];
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

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token'])) {
    if (!hash_equals($_SESSION['csrf_token'], (string)$_POST['csrf_token'])) {
        $errors[] = 'CSRF token inválido.';
    } else {
        $playerId = trim((string)($_POST['player_id'] ?? ''));
        $packId = trim((string)($_POST['pack_id'] ?? ''));
        if ($playerId === '' || $packId === '') {
            $errors[] = 'Debes seleccionar jugador y sobre.';
        } else {
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/open_uft_pack', $serviceRoleKey, [
                'p_player_id' => $playerId,
                'p_pack_id' => $packId,
            ]);
            if ($result['ok']) {
                $success = 'Compra/apertura procesada.';
                $openResult = $result['data'];
            } else {
                $errors[] = 'No se pudo abrir sobre: ' . $result['error'];
            }
        }
    }
}

$storeSlots = [];
$players = [];
if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $slotsResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_store_slots', $serviceRoleKey, []);
    if ($slotsResp['ok'] && is_array($slotsResp['data'])) {
        $storeSlots = $slotsResp['data'];
    }
    $playersResp = api_request('GET', $supabaseUrl . '/rest/v1/player_accounts?select=id,username&order=created_at.desc&limit=200', $serviceRoleKey);
    if ($playersResp['ok'] && is_array($playersResp['data'])) {
        $players = $playersResp['data'];
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Tienda UFT</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body{margin:0;padding:20px;background:#020617;color:#e2e8f0;font-family:Inter,Arial,sans-serif}
        .panel{background:#0f172a;border:1px solid #1e293b;border-radius:12px;padding:14px;margin-bottom:14px}
        .store{display:grid;grid-template-columns:repeat(auto-fit,minmax(250px,1fr));gap:12px}
        .pack{background:#111827;border:1px solid #334155;border-radius:12px;padding:12px}
        .pack img{width:100%;height:170px;object-fit:cover;border-radius:10px;background:#020617;border:1px solid #334155}
        select,input,button{padding:10px;border-radius:8px;border:1px solid #334155;background:#020617;color:#e2e8f0}
        button{background:#2563eb;border:none;color:#fff;font-weight:700;cursor:pointer;width:100%}
        .muted{color:#94a3b8;font-size:.9rem}
        .ok{border-color:#22c55e}.err{border-color:#ef4444}
        code{background:#111827;padding:2px 6px;border-radius:6px}
    </style>
</head>
<body>
<h1>Tienda de sobres UFT</h1>
<p><a href="admin.php" style="color:#93c5fd;">← Volver al panel principal</a></p>

<?php foreach ($errors as $err): ?><div class="panel err"><?php echo h($err); ?></div><?php endforeach; ?>
<?php if ($success !== ''): ?><div class="panel ok"><?php echo h($success); ?></div><?php endif; ?>

<div class="panel">
    <h3 style="margin-top:0;">Jugador comprador</h3>
    <form method="post" id="buy-form">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="pack_id" id="pack_id_field" value="">
        <select name="player_id" required>
            <option value="">Selecciona jugador</option>
            <?php foreach ($players as $p): ?>
                <option value="<?php echo h((string)($p['id'] ?? '')); ?>"><?php echo h((string)($p['username'] ?? '')); ?> · <?php echo h((string)($p['id'] ?? '')); ?></option>
            <?php endforeach; ?>
        </select>
    </form>
</div>

<div class="store">
    <?php foreach ($storeSlots as $slot): ?>
        <?php $packId = (string)($slot['pack_id'] ?? ''); ?>
        <div class="pack">
            <?php if ((string)($slot['image_url'] ?? '') !== ''): ?>
                <img src="<?php echo h((string)$slot['image_url']); ?>" alt="<?php echo h((string)($slot['pack_name'] ?? $packId)); ?>">
            <?php else: ?>
                <div style="height:170px;display:grid;place-items:center;border:1px dashed #334155;border-radius:10px;">Sin imagen</div>
            <?php endif; ?>
            <h3><?php echo h((string)($slot['pack_name'] ?? $packId)); ?></h3>
            <div class="muted">ID: <code><?php echo h($packId); ?></code></div>
            <div class="muted">Costo: <?php echo h((string)($slot['cost_coins'] ?? 0)); ?> UFT Coins / <?php echo h((string)($slot['cost_points'] ?? 0)); ?> UFT Points</div>
            <div class="muted">Cartas: <?php echo h((string)($slot['cards_count'] ?? 1)); ?></div>
            <div class="muted">Policy: <?php echo h((string)($slot['duplicate_policy'] ?? 'allow')); ?></div>
            <div class="muted">Tiempo restante: <?php echo h((string)($slot['remaining_seconds'] ?? 0)); ?>s</div>
            <button type="button" onclick="buyPack('<?php echo h($packId); ?>')">Comprar / Abrir</button>
        </div>
    <?php endforeach; ?>
</div>

<?php if (is_array($openResult)): ?>
<div class="panel">
    <h3 style="margin-top:0;">Resultado apertura</h3>
    <p>Won cards: <code><?php echo h(json_encode($openResult['won_cards'] ?? [])); ?></code></p>
    <p>Duplicados: <?php echo h((string)($openResult['duplicates'] ?? 0)); ?></p>
    <p>Compensación coins: <?php echo h((string)($openResult['duplicate_coins'] ?? 0)); ?></p>
</div>
<?php endif; ?>

<script>
function buyPack(packId) {
  const form = document.getElementById('buy-form');
  const input = document.getElementById('pack_id_field');
  input.value = packId;
  form.submit();
}
</script>
</body>
</html>
