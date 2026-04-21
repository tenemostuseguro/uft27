<?php
session_start();

function env_or_empty(string $key): string {
    $value = getenv($key);
    return $value === false ? '' : trim($value);
}

function h(string $value): string {
    return htmlspecialchars($value, ENT_QUOTES, 'UTF-8');
}

function format_countdown(int $expiresAtUnix): string {
    $remaining = max(0, $expiresAtUnix - time());
    $hours = intdiv($remaining, 3600);
    $minutes = intdiv($remaining % 3600, 60);
    $seconds = $remaining % 60;
    return sprintf('%02d:%02d:%02d', $hours, $minutes, $seconds);
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

if (!isset($_SESSION['csrf_token'])) {
    $_SESSION['csrf_token'] = bin2hex(random_bytes(32));
}

if (!isset($_SESSION['is_admin']) || $_SESSION['is_admin'] !== true) {
    header('Location: admin.php');
    exit;
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['csrf_token']) && hash_equals($_SESSION['csrf_token'], (string) $_POST['csrf_token'])) {
    $action = (string) ($_POST['action'] ?? '');

    if ($action === 'upsert_listing') {
        $payload = [
            'p_listing_id' => trim((string) ($_POST['listing_id'] ?? '')),
            'p_card_id' => trim((string) ($_POST['card_id'] ?? '')),
            'p_price' => (int) ($_POST['start_price'] ?? 100),
            'p_start_price' => (int) ($_POST['start_price'] ?? 100),
            'p_current_bid' => (int) ($_POST['current_bid'] ?? 0),
            'p_buy_now_price' => (int) ($_POST['buy_now_price'] ?? 1000),
            'p_highest_bidder' => trim((string) ($_POST['highest_bidder'] ?? '')),
            'p_expires_at_unix' => (int) ($_POST['expires_at_unix'] ?? (time() + 7200)),
            'p_seller' => trim((string) ($_POST['seller'] ?? 'npc_market')),
            'p_active' => isset($_POST['active']),
        ];
        $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_market_listing', $serviceRoleKey, $payload);
        if ($result['ok']) {
            $success = 'Publicación guardada.';
        } else {
            $errors[] = 'No se pudo guardar la publicación: ' . $result['error'];
        }
    }

    if ($action === 'delete_listing') {
        $listingId = trim((string) ($_POST['listing_id'] ?? ''));
        if ($listingId === '') {
            $errors[] = 'listing_id inválido.';
        } else {
            $result = api_request('DELETE', $supabaseUrl . '/rest/v1/uft_market_catalog?listing_id=eq.' . rawurlencode($listingId), $serviceRoleKey);
            if ($result['ok']) {
                $success = 'Publicación eliminada.';
            } else {
                $errors[] = 'No se pudo eliminar: ' . $result['error'];
            }
        }
    }
}

$listings = [];
$cards = [];
if ($supabaseUrl !== '' && $serviceRoleKey !== '') {
    $listingsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_market_listings', $serviceRoleKey, []);
    if ($listingsResult['ok'] && is_array($listingsResult['data'])) {
        $listings = $listingsResult['data'];
    }

    $cardsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_cards', $serviceRoleKey, []);
    if ($cardsResult['ok'] && is_array($cardsResult['data'])) {
        $cards = $cardsResult['data'];
    }
}
?>
<!doctype html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <title>UFT Market Admin</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {font-family: Inter, Arial, sans-serif; margin:0; padding:20px; background:#020617; color:#e2e8f0;}
        .panel {background:#0f172a; border:1px solid #1e293b; border-radius:12px; padding:16px; margin-top:16px;}
        input, select {padding:8px; border-radius:8px; border:1px solid #334155; background:#0b1220; color:#e2e8f0;}
        .grid {display:grid; gap:10px; max-width:900px;}
        .btn {padding:8px 12px; border:none; border-radius:8px; color:#fff; cursor:pointer;}
        .primary {background:#2563eb;} .danger {background:#dc2626;} .secondary {background:#475569;}
        table {width:100%; border-collapse:collapse; margin-top:12px;}
        th, td {padding:10px; border-bottom:1px solid #1e293b; text-align:left;}
        code {background:#111827; padding:2px 6px; border-radius:6px;}
        .market-row {display:grid; grid-template-columns: 120px 1fr; gap:10px; align-items:center;}
        .thumb {width:110px; height:150px; border-radius:8px; object-fit:cover; border:1px solid #334155; background:#020617;}
    </style>
</head>
<body>
<h1>Administración de mercado UFT</h1>
<p><a href="admin.php" style="color:#93c5fd;">← Volver al panel principal</a></p>

<?php foreach ($errors as $error): ?><div class="panel" style="border-color:#ef4444;"><?php echo h($error); ?></div><?php endforeach; ?>
<?php if ($success !== ''): ?><div class="panel" style="border-color:#22c55e;"><?php echo h($success); ?></div><?php endif; ?>

<div class="panel">
    <h2>Nueva / editar subasta</h2>
    <form method="post" class="grid">
        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
        <input type="hidden" name="action" value="upsert_listing">
        <input type="text" name="listing_id" placeholder="listing_id" required>
        <select name="card_id" required>
            <option value="">Selecciona card_id</option>
            <?php foreach ($cards as $card): ?>
                <option value="<?php echo h((string) ($card['card_id'] ?? '')); ?>"><?php echo h((string) ($card['card_id'] ?? '')); ?> · <?php echo h((string) ($card['player_id'] ?? '')); ?></option>
            <?php endforeach; ?>
        </select>
        <input type="number" min="100" name="start_price" value="1000" placeholder="Start Price">
        <input type="number" min="0" name="current_bid" value="0" placeholder="Current Bid">
        <input type="number" min="100" name="buy_now_price" value="2500" placeholder="Buy Now">
        <input type="text" name="highest_bidder" value="" placeholder="Highest Bidder">
        <input type="number" min="0" name="expires_at_unix" value="<?php echo h((string) (time() + 7200)); ?>" placeholder="Expiry Unix">
        <input type="text" name="seller" value="npc_market" placeholder="Seller">
        <label><input type="checkbox" name="active" checked> Activo</label>
        <button type="submit" class="btn primary" style="width:max-content;">Guardar subasta</button>
    </form>
</div>

<div class="panel">
    <h2>Subastas activas</h2>
    <table>
        <thead><tr><th>card</th><th>listing_id</th><th>start</th><th>current bid</th><th>buy now</th><th>countdown</th><th>seller</th><th>active</th><th>acción</th></tr></thead>
        <tbody>
        <?php foreach ($listings as $listing): ?>
            <?php
                $cardId = (string) ($listing['card_id'] ?? '');
                $cardImage = '';
                foreach ($cards as $cardRow) {
                    if ((string) ($cardRow['card_id'] ?? '') === $cardId) {
                        $cardImage = (string) ($cardRow['face_url'] ?? '');
                        break;
                    }
                }
            ?>
            <tr>
                <td>
                    <div class="market-row">
                        <?php if ($cardImage !== ''): ?>
                            <img class="thumb" src="<?php echo h($cardImage); ?>" alt="card">
                        <?php else: ?>
                            <div class="thumb"></div>
                        <?php endif; ?>
                        <div><code><?php echo h($cardId); ?></code></div>
                    </div>
                </td>
                <td><code><?php echo h((string) ($listing['listing_id'] ?? '')); ?></code></td>
                <td><?php echo h((string) ($listing['start_price'] ?? $listing['price'] ?? '0')); ?></td>
                <td><?php echo h((string) ($listing['current_bid'] ?? '0')); ?></td>
                <td><?php echo h((string) ($listing['buy_now_price'] ?? '0')); ?></td>
                <td>
                    <?php $expires = (int) ($listing['expires_at_unix'] ?? 0); ?>
                    <?php echo h(format_countdown($expires)); ?><br>
                    <small><?php echo h((string) $expires); ?></small>
                </td>
                <td><?php echo h((string) ($listing['seller'] ?? '')); ?></td>
                <td><?php echo ((bool) ($listing['active'] ?? false)) ? 'Sí' : 'No'; ?></td>
                <td>
                    <form method="post" onsubmit="return confirm('¿Eliminar publicación?');">
                        <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                        <input type="hidden" name="action" value="delete_listing">
                        <input type="hidden" name="listing_id" value="<?php echo h((string) ($listing['listing_id'] ?? '')); ?>">
                        <button type="submit" class="btn danger">Eliminar</button>
                    </form>
                </td>
            </tr>
        <?php endforeach; ?>
        </tbody>
    </table>
</div>
</body>
</html>
