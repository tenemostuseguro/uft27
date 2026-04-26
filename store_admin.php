<?php
session_start();

function env_or_empty(string $key): string {
    $v = getenv($key);
    return $v === false ? '' : trim($v);
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

function to_int($value, int $fallback = 0): int {
    if (is_numeric($value)) {
        return (int) $value;
    }
    return $fallback;
}

function format_countdown(int $remaining): string {
    $remaining = max(0, $remaining);
    $hours = intdiv($remaining, 3600);
    $minutes = intdiv($remaining % 3600, 60);
    $seconds = $remaining % 60;
    return sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds);
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
        return [
            'ok' => false,
            'status' => $status,
            'error' => is_array($decoded) ? (string) ($decoded['message'] ?? $decoded['error'] ?? json_encode($decoded)) : $response,
            'data' => $decoded,
        ];
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
$selectedPlayerId = trim((string) ($_GET['player_id'] ?? ''));
$selectedPackFilter = trim((string) ($_GET['pack_filter'] ?? ''));
$selectedStatus = trim((string) ($_GET['status_filter'] ?? 'active'));

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token'])) {
    if (!hash_equals($_SESSION['csrf_token'], (string) $_POST['csrf_token'])) {
        $errors[] = 'CSRF token inválido.';
    } else {
        $action = trim((string) ($_POST['action'] ?? ''));

        if ($action === 'open_pack') {
            $selectedPlayerId = trim((string) ($_POST['player_id'] ?? ''));
            $packId = trim((string) ($_POST['pack_id'] ?? ''));
            if ($selectedPlayerId === '' || $packId === '') {
                $errors[] = 'Debes seleccionar jugador y sobre.';
            } else {
                $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/open_uft_pack', $serviceRoleKey, [
                    'p_player_id' => $selectedPlayerId,
                    'p_pack_id' => $packId,
                ]);
                if ($result['ok']) {
                    $success = 'Sobre abierto correctamente.';
                    $openResult = $result['data'];
                } else {
                    $errors[] = 'No se pudo abrir sobre: ' . $result['error'];
                }
            }
        }

        if ($action === 'save_slot') {
            $slotId = trim((string) ($_POST['slot_id'] ?? ''));
            $payload = [
                'p_slot_id' => $slotId === '' ? null : $slotId,
                'p_pack_id' => trim((string) ($_POST['pack_id'] ?? '')),
                'p_starts_at_unix' => to_int($_POST['starts_at_unix'] ?? 0),
                'p_ends_at_unix' => to_int($_POST['ends_at_unix'] ?? 0),
                'p_active' => isset($_POST['active']),
                'p_sort_order' => to_int($_POST['sort_order'] ?? 0),
                'p_manual_note' => trim((string) ($_POST['manual_note'] ?? '')),
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_store_slot', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = ($slotId === '' ? 'Slot creado.' : 'Slot actualizado.');
            } else {
                $errors[] = 'No se pudo guardar slot: ' . $result['error'];
            }
        }

        if ($action === 'deactivate_slot') {
            $payload = [
                'p_slot_id' => trim((string) ($_POST['slot_id'] ?? '')),
                'p_pack_id' => trim((string) ($_POST['pack_id'] ?? '')),
                'p_starts_at_unix' => to_int($_POST['starts_at_unix'] ?? 0),
                'p_ends_at_unix' => to_int($_POST['ends_at_unix'] ?? 0),
                'p_active' => false,
                'p_sort_order' => to_int($_POST['sort_order'] ?? 0),
                'p_manual_note' => trim((string) ($_POST['manual_note'] ?? '')),
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_store_slot', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Slot desactivado.';
            } else {
                $errors[] = 'No se pudo desactivar slot: ' . $result['error'];
            }
        }

        if ($action === 'duplicate_slot') {
            $starts = to_int($_POST['starts_at_unix'] ?? time());
            $ends = to_int($_POST['ends_at_unix'] ?? (time() + 86400));
            $duration = max(3600, $ends - $starts);
            $newStart = time();
            $payload = [
                'p_slot_id' => null,
                'p_pack_id' => trim((string) ($_POST['pack_id'] ?? '')),
                'p_starts_at_unix' => $newStart,
                'p_ends_at_unix' => $newStart + $duration,
                'p_active' => true,
                'p_sort_order' => to_int($_POST['sort_order'] ?? 0),
                'p_manual_note' => trim((string) ($_POST['manual_note'] ?? '')) . ' (duplicado)',
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_store_slot', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Slot duplicado y activado desde ahora.';
            } else {
                $errors[] = 'No se pudo duplicar slot: ' . $result['error'];
            }
        }
    }
}

$packs = [];
$players = [];
$activeSlots = [];
$allSlots = [];
$packOpenings = [];
$playerInventory = [];

if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $packsResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_packs', $serviceRoleKey, []);
    if ($packsResp['ok'] && is_array($packsResp['data'])) {
        $packs = $packsResp['data'];
    }

    $playersResp = api_request('GET', $supabaseUrl . '/rest/v1/player_accounts?select=id,username&order=created_at.desc&limit=500', $serviceRoleKey);
    if ($playersResp['ok'] && is_array($playersResp['data'])) {
        $players = $playersResp['data'];
    }

    $activeSlotsResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_store_slots', $serviceRoleKey, []);
    if ($activeSlotsResp['ok'] && is_array($activeSlotsResp['data'])) {
        $activeSlots = $activeSlotsResp['data'];
    }

    $allSlotsResp = api_request('GET', $supabaseUrl . '/rest/v1/uft_store_slots?select=slot_id,pack_id,starts_at_unix,ends_at_unix,sort_order,manual_note,active,updated_at&order=updated_at.desc&limit=300', $serviceRoleKey);
    if ($allSlotsResp['ok'] && is_array($allSlotsResp['data'])) {
        $allSlots = $allSlotsResp['data'];
    }

    $openingsResp = api_request('GET', $supabaseUrl . '/rest/v1/uft_pack_openings?select=opening_id,player_id,pack_id,won_cards,duplicates,duplicate_coins,opened_at&order=opened_at.desc&limit=100', $serviceRoleKey);
    if ($openingsResp['ok'] && is_array($openingsResp['data'])) {
        $packOpenings = $openingsResp['data'];
    }

    if ($selectedPlayerId !== '') {
        $inventoryResp = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_player_uft_cards', $serviceRoleKey, [
            'p_player_id' => $selectedPlayerId,
        ]);
        if ($inventoryResp['ok'] && is_array($inventoryResp['data'])) {
            $playerInventory = $inventoryResp['data'];
        }
    }
}

$packsById = [];
foreach ($packs as $pack) {
    $packsById[(string) ($pack['pack_id'] ?? '')] = $pack;
}

$filteredSlots = [];
$nowUnix = time();
foreach ($allSlots as $slot) {
    $packId = (string) ($slot['pack_id'] ?? '');
    if ($selectedPackFilter !== '' && $packId !== $selectedPackFilter) {
        continue;
    }
    $isActive = (bool) ($slot['active'] ?? false);
    $ends = to_int($slot['ends_at_unix'] ?? 0);
    $starts = to_int($slot['starts_at_unix'] ?? 0);
    $isLive = $isActive && $starts <= $nowUnix && $ends > $nowUnix;
    if ($selectedStatus === 'live' && !$isLive) {
        continue;
    }
    if ($selectedStatus === 'active' && !$isActive) {
        continue;
    }
    if ($selectedStatus === 'inactive' && $isActive) {
        continue;
    }
    $filteredSlots[] = $slot;
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>Tienda UFT · Admin avanzada</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {margin:0; padding:20px; background:#020617; color:#e2e8f0; font-family:Inter,Arial,sans-serif;}
        .panel {background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:14px; margin-bottom:14px;}
        .ok {border-color:#22c55e;} .err {border-color:#ef4444;}
        .grid {display:grid; grid-template-columns:repeat(auto-fit,minmax(240px,1fr)); gap:10px;}
        .store {display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:12px;}
        .pack {background:#111827; border:1px solid #334155; border-radius:12px; padding:12px;}
        .pack img {width:100%; height:170px; object-fit:cover; border-radius:10px; background:#020617; border:1px solid #334155;}
        input, select, button, textarea {padding:10px; border-radius:8px; border:1px solid #334155; background:#020617; color:#e2e8f0;}
        button {cursor:pointer; background:#2563eb; border:none; color:#fff; font-weight:700;}
        .btn-danger {background:#dc2626;}
        .btn-secondary {background:#475569;}
        table {width:100%; border-collapse:collapse;}
        th, td {padding:8px; border-bottom:1px solid #1e293b; text-align:left; vertical-align:top;}
        code {background:#111827; padding:2px 6px; border-radius:6px;}
        .muted {color:#94a3b8; font-size:.9rem;}
        .row-actions {display:flex; gap:6px; flex-wrap:wrap;}
    </style>
</head>
<body>
<h1>Tienda UFT · Admin avanzada</h1>
<p>
    <a href="admin.php" style="color:#93c5fd;">← Volver al panel principal</a> ·
    <a href="pack_system_admin.php" style="color:#93c5fd;">Sistema de sobres</a>
</p>

<?php foreach ($errors as $err): ?><div class="panel err"><?php echo h($err); ?></div><?php endforeach; ?>
<?php if ($success !== ''): ?><div class="panel ok"><?php echo h($success); ?></div><?php endif; ?>

<div class="panel">
    <h3 style="margin-top:0;">Métricas rápidas</h3>
    <div class="grid">
        <div><strong>Slots activos (RPC):</strong> <?php echo count($activeSlots); ?></div>
        <div><strong>Slots totales:</strong> <?php echo count($allSlots); ?></div>
        <div><strong>Sobres catalogados:</strong> <?php echo count($packs); ?></div>
        <div><strong>Aperturas recientes:</strong> <?php echo count($packOpenings); ?></div>
    </div>
</div>

<div class="panel">
    <h3 style="margin-top:0;">Crear / editar slot de tienda</h3>
    <form method="post" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="save_slot">
        <input type="text" name="slot_id" placeholder="slot_id UUID (vacío para crear)">
        <select name="pack_id" required>
            <option value="">Selecciona pack</option>
            <?php foreach ($packs as $pack): ?>
                <option value="<?php echo h((string) ($pack['pack_id'] ?? '')); ?>">
                    <?php echo h((string) ($pack['name'] ?? '')); ?> · <?php echo h((string) ($pack['pack_id'] ?? '')); ?>
                </option>
            <?php endforeach; ?>
        </select>
        <input type="number" name="starts_at_unix" value="<?php echo h((string) time()); ?>" placeholder="Inicio unix" required>
        <input type="number" name="ends_at_unix" value="<?php echo h((string) (time() + 86400)); ?>" placeholder="Fin unix" required>
        <input type="number" name="sort_order" value="0" placeholder="Orden">
        <input type="text" name="manual_note" placeholder="Nota manual (ej. Promo fin de semana)">
        <label><input type="checkbox" name="active" checked> Activo</label>
        <button type="submit">Guardar slot</button>
    </form>
</div>

<div class="panel">
    <h3 style="margin-top:0;">Apertura rápida (simulación compra)</h3>
    <form method="post" id="buy-form" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="open_pack">
        <input type="hidden" name="pack_id" id="pack_id_field" value="">
        <select name="player_id" required>
            <option value="">Selecciona jugador</option>
            <?php foreach ($players as $p): ?>
                <option value="<?php echo h((string) ($p['id'] ?? '')); ?>" <?php echo $selectedPlayerId === (string) ($p['id'] ?? '') ? 'selected' : ''; ?>>
                    <?php echo h((string) ($p['username'] ?? '')); ?> · <?php echo h((string) ($p['id'] ?? '')); ?>
                </option>
            <?php endforeach; ?>
        </select>
    </form>
</div>

<div class="store">
    <?php foreach ($activeSlots as $slot): ?>
        <?php
            $packId = (string) ($slot['pack_id'] ?? '');
            $remaining = to_int($slot['remaining_seconds'] ?? 0);
        ?>
        <div class="pack">
            <?php if ((string) ($slot['image_url'] ?? '') !== ''): ?>
                <img src="<?php echo h((string) $slot['image_url']); ?>" alt="<?php echo h((string) ($slot['pack_name'] ?? $packId)); ?>">
            <?php else: ?>
                <div style="height:170px;display:grid;place-items:center;border:1px dashed #334155;border-radius:10px;">Sin imagen</div>
            <?php endif; ?>
            <h3><?php echo h((string) ($slot['pack_name'] ?? $packId)); ?></h3>
            <div class="muted">ID: <code><?php echo h($packId); ?></code></div>
            <div class="muted">Costo: <?php echo h((string) ($slot['cost_coins'] ?? 0)); ?> Coins / <?php echo h((string) ($slot['cost_points'] ?? 0)); ?> Points</div>
            <div class="muted">Cartas: <?php echo h((string) ($slot['cards_count'] ?? 1)); ?></div>
            <div class="muted">Tiempo restante: <?php echo h(format_countdown($remaining)); ?></div>
            <button type="button" onclick="buyPack('<?php echo h($packId); ?>')">Comprar / Abrir</button>
        </div>
    <?php endforeach; ?>
</div>

<?php if (is_array($openResult)): ?>
<div class="panel">
    <h3 style="margin-top:0;">Resultado apertura</h3>
    <p>Won cards: <code><?php echo h(json_encode($openResult['won_cards'] ?? [])); ?></code></p>
    <p>Duplicados: <?php echo h((string) ($openResult['duplicates'] ?? 0)); ?></p>
    <p>Compensación coins: <?php echo h((string) ($openResult['duplicate_coins'] ?? 0)); ?></p>
</div>
<?php endif; ?>

<div class="panel">
    <h3 style="margin-top:0;">Inventario del jugador seleccionado</h3>
    <table>
        <thead><tr><th>card_id</th><th>cantidad</th><th>updated_at</th></tr></thead>
        <tbody>
        <?php if (count($playerInventory) === 0): ?>
            <tr><td colspan="3">Sin cartas o jugador no seleccionado.</td></tr>
        <?php endif; ?>
        <?php foreach ($playerInventory as $row): ?>
            <tr>
                <td><code><?php echo h((string) ($row['card_id'] ?? '')); ?></code></td>
                <td><?php echo h((string) ($row['quantity'] ?? '0')); ?></td>
                <td><?php echo h((string) ($row['updated_at'] ?? '')); ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>

<div class="panel">
    <h3 style="margin-top:0;">Slots (gestión avanzada)</h3>
    <form method="get" class="grid" style="margin-bottom:10px;">
        <select name="pack_filter">
            <option value="">Filtrar por pack (todos)</option>
            <?php foreach ($packs as $pack): ?>
                <?php $pid = (string) ($pack['pack_id'] ?? ''); ?>
                <option value="<?php echo h($pid); ?>" <?php echo $selectedPackFilter === $pid ? 'selected' : ''; ?>>
                    <?php echo h((string) ($pack['name'] ?? '')); ?> · <?php echo h($pid); ?>
                </option>
            <?php endforeach; ?>
        </select>
        <select name="status_filter">
            <option value="active" <?php echo $selectedStatus === 'active' ? 'selected' : ''; ?>>Solo activos</option>
            <option value="live" <?php echo $selectedStatus === 'live' ? 'selected' : ''; ?>>Solo en vivo (activos + dentro de tiempo)</option>
            <option value="inactive" <?php echo $selectedStatus === 'inactive' ? 'selected' : ''; ?>>Solo inactivos</option>
            <option value="all" <?php echo $selectedStatus === 'all' ? 'selected' : ''; ?>>Todos</option>
        </select>
        <button type="submit" class="btn-secondary">Aplicar filtros</button>
    </form>
    <table>
        <thead><tr><th>slot</th><th>pack</th><th>inicio/fin</th><th>activo</th><th>nota</th><th>acciones</th></tr></thead>
        <tbody>
        <?php if (count($filteredSlots) === 0): ?>
            <tr><td colspan="6">No hay slots con esos filtros.</td></tr>
        <?php endif; ?>
        <?php foreach ($filteredSlots as $slot): ?>
            <?php
                $slotId = (string) ($slot['slot_id'] ?? '');
                $packId = (string) ($slot['pack_id'] ?? '');
                $starts = to_int($slot['starts_at_unix'] ?? 0);
                $ends = to_int($slot['ends_at_unix'] ?? 0);
                $isActive = (bool) ($slot['active'] ?? false);
            ?>
            <tr>
                <td><code><?php echo h($slotId); ?></code></td>
                <td><code><?php echo h($packId); ?></code></td>
                <td><?php echo h((string) $starts); ?> → <?php echo h((string) $ends); ?></td>
                <td><?php echo $isActive ? 'Sí' : 'No'; ?></td>
                <td><?php echo h((string) ($slot['manual_note'] ?? '')); ?></td>
                <td>
                    <div class="row-actions">
                        <form method="post">
                            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                            <input type="hidden" name="action" value="duplicate_slot">
                            <input type="hidden" name="slot_id" value="<?php echo h($slotId); ?>">
                            <input type="hidden" name="pack_id" value="<?php echo h($packId); ?>">
                            <input type="hidden" name="starts_at_unix" value="<?php echo h((string) $starts); ?>">
                            <input type="hidden" name="ends_at_unix" value="<?php echo h((string) $ends); ?>">
                            <input type="hidden" name="sort_order" value="<?php echo h((string) ($slot['sort_order'] ?? 0)); ?>">
                            <input type="hidden" name="manual_note" value="<?php echo h((string) ($slot['manual_note'] ?? '')); ?>">
                            <button type="submit" class="btn-secondary">Duplicar</button>
                        </form>
                        <?php if ($isActive): ?>
                            <form method="post" onsubmit="return confirm('¿Desactivar este slot?');">
                                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                                <input type="hidden" name="action" value="deactivate_slot">
                                <input type="hidden" name="slot_id" value="<?php echo h($slotId); ?>">
                                <input type="hidden" name="pack_id" value="<?php echo h($packId); ?>">
                                <input type="hidden" name="starts_at_unix" value="<?php echo h((string) $starts); ?>">
                                <input type="hidden" name="ends_at_unix" value="<?php echo h((string) $ends); ?>">
                                <input type="hidden" name="sort_order" value="<?php echo h((string) ($slot['sort_order'] ?? 0)); ?>">
                                <input type="hidden" name="manual_note" value="<?php echo h((string) ($slot['manual_note'] ?? '')); ?>">
                                <button type="submit" class="btn-danger">Desactivar</button>
                            </form>
                        <?php endif; ?>
                    </div>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>

<div class="panel">
    <h3 style="margin-top:0;">Últimas aperturas</h3>
    <table>
        <thead><tr><th>opened_at</th><th>player_id</th><th>pack_id</th><th>won_cards</th><th>dup</th><th>coins</th></tr></thead>
        <tbody>
        <?php if (count($packOpenings) === 0): ?>
            <tr><td colspan="6">Sin aperturas registradas.</td></tr>
        <?php endif; ?>
        <?php foreach ($packOpenings as $open): ?>
            <tr>
                <td><?php echo h((string) ($open['opened_at'] ?? '')); ?></td>
                <td><code><?php echo h((string) ($open['player_id'] ?? '')); ?></code></td>
                <td><code><?php echo h((string) ($open['pack_id'] ?? '')); ?></code></td>
                <td><code><?php echo h((string) json_encode($open['won_cards'] ?? [])); ?></code></td>
                <td><?php echo h((string) ($open['duplicates'] ?? 0)); ?></td>
                <td><?php echo h((string) ($open['duplicate_coins'] ?? 0)); ?></td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>

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
