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

        if ($action === 'upsert_uft_player') {
            $payload = [
                'p_player_id' => trim((string) ($_POST['p_player_id'] ?? '')),
                'p_name' => trim((string) ($_POST['p_name'] ?? '')),
                'p_main_position' => trim((string) ($_POST['p_main_position'] ?? 'P')),
                'p_secondary_positions' => json_decode((string) ($_POST['p_secondary_positions'] ?? '[]'), true),
                'p_dominant_foot' => trim((string) ($_POST['p_dominant_foot'] ?? '')),
                'p_nationality' => trim((string) ($_POST['p_nationality'] ?? '')),
                'p_club' => trim((string) ($_POST['p_club'] ?? '')),
                'p_photo_face_url' => trim((string) ($_POST['p_photo_face_url'] ?? '')),
                'p_metadata' => json_decode((string) ($_POST['p_metadata'] ?? '{}'), true),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_player';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Jugador UFT guardado en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar jugador UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_card') {
            $payload = [
                'p_card_id' => trim((string) ($_POST['p_card_id'] ?? '')),
                'p_player_id' => trim((string) ($_POST['p_card_player_id'] ?? '')),
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
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_card';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Carta UFT guardada en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar carta UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_card_type') {
            $payload = [
                'p_card_type' => trim((string) ($_POST['p_card_type_id'] ?? '')),
                'p_display_name' => trim((string) ($_POST['p_card_type_display_name'] ?? '')),
                'p_rarity_default' => trim((string) ($_POST['p_card_type_rarity_default'] ?? 'Common')),
                'p_style' => json_decode((string) ($_POST['p_card_type_style'] ?? '{}'), true),
                'p_active' => isset($_POST['p_card_type_active']),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_card_type';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Tipo de carta UFT guardado en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar tipo de carta UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_event') {
            $payload = [
                'p_event_id' => trim((string) ($_POST['p_event_id'] ?? '')),
                'p_name' => trim((string) ($_POST['p_event_name'] ?? '')),
                'p_description' => trim((string) ($_POST['p_event_description'] ?? '')),
                'p_start_unix' => (int) ($_POST['p_start_unix'] ?? 0),
                'p_end_unix' => (int) ($_POST['p_end_unix'] ?? 0),
                'p_active' => isset($_POST['p_active']),
                'p_access_cost_coins' => (int) ($_POST['p_access_cost_coins'] ?? 0),
                'p_rules' => json_decode((string) ($_POST['p_rules'] ?? '{}'), true),
                'p_rewards' => json_decode((string) ($_POST['p_rewards'] ?? '[]'), true),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_event';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Evento UFT guardado en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar evento UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_pack') {
            $payload = [
                'p_pack_id' => trim((string) ($_POST['p_pack_id'] ?? '')),
                'p_name' => trim((string) ($_POST['p_pack_name'] ?? '')),
                'p_cost_coins' => (int) ($_POST['p_cost_coins'] ?? 0),
                'p_cost_points' => (int) ($_POST['p_cost_points'] ?? 0),
                'p_cards_count' => (int) ($_POST['p_cards_count'] ?? 1),
                'p_duplicate_policy' => trim((string) ($_POST['p_duplicate_policy'] ?? 'allow')),
                'p_pool' => json_decode((string) ($_POST['p_pool'] ?? '[]'), true),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_pack';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Sobre UFT guardado en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar sobre UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_market_listing') {
            $payload = [
                'p_listing_id' => trim((string) ($_POST['p_listing_id'] ?? '')),
                'p_card_id' => trim((string) ($_POST['p_listing_card_id'] ?? '')),
                'p_price' => (int) ($_POST['p_price'] ?? 100),
                'p_seller' => trim((string) ($_POST['p_seller'] ?? 'npc_market')),
                'p_active' => isset($_POST['p_listing_active']),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_market_listing';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Publicación de mercado UFT guardada en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar publicación de mercado UFT: ' . $result['error'];
            }
        }

        if ($action === 'upsert_uft_season') {
            $payload = [
                'p_season_id' => trim((string) ($_POST['p_season_id'] ?? '')),
                'p_name' => trim((string) ($_POST['p_season_name'] ?? '')),
                'p_start_unix' => (int) ($_POST['p_season_start_unix'] ?? 0),
                'p_end_unix' => (int) ($_POST['p_season_end_unix'] ?? 0),
                'p_levels' => json_decode((string) ($_POST['p_levels'] ?? '[]'), true),
            ];
            $rpcUrl = $supabaseUrl . '/rest/v1/rpc/upsert_uft_season';
            $result = api_request('POST', $rpcUrl, $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Temporada UFT guardada en Supabase.';
            } else {
                $errors[] = 'No se pudo guardar temporada UFT: ' . $result['error'];
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

        if ($action === 'upsert_country') {
            $payload = [
                'p_country_id' => ($id = trim((string) ($_POST['country_id'] ?? ''))) === '' ? null : $id,
                'p_name' => trim((string) ($_POST['country_name'] ?? '')),
                'p_iso_code' => trim((string) ($_POST['country_iso_code'] ?? '')),
                'p_logo_url' => trim((string) ($_POST['country_logo_url'] ?? '')),
                'p_active' => isset($_POST['country_active']),
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_country', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'País guardado correctamente.';
            } else {
                $errors[] = 'No se pudo guardar país: ' . $result['error'];
            }
        }

        if ($action === 'upsert_league') {
            $payload = [
                'p_league_id' => ($id = trim((string) ($_POST['league_id'] ?? ''))) === '' ? null : $id,
                'p_country_id' => ($id = trim((string) ($_POST['league_country_id'] ?? ''))) === '' ? null : $id,
                'p_name' => trim((string) ($_POST['league_name'] ?? '')),
                'p_tier_level' => (int) ($_POST['league_tier_level'] ?? 1),
                'p_logo_url' => trim((string) ($_POST['league_logo_url'] ?? '')),
                'p_active' => isset($_POST['league_active']),
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_league', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Liga guardada correctamente.';
            } else {
                $errors[] = 'No se pudo guardar liga: ' . $result['error'];
            }
        }

        if ($action === 'upsert_club') {
            $payload = [
                'p_club_id' => ($id = trim((string) ($_POST['club_id'] ?? ''))) === '' ? null : $id,
                'p_league_id' => ($id = trim((string) ($_POST['club_league_id'] ?? ''))) === '' ? null : $id,
                'p_name' => trim((string) ($_POST['club_name'] ?? '')),
                'p_logo_url' => trim((string) ($_POST['club_logo_url'] ?? '')),
                'p_active' => isset($_POST['club_active']),
            ];
            $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/upsert_uft_club', $serviceRoleKey, $payload);
            if ($result['ok']) {
                $success = 'Club guardado correctamente.';
            } else {
                $errors[] = 'No se pudo guardar club: ' . $result['error'];
            }
        }

        if ($action === 'assign_user_club') {
            $targetUserId = trim((string) ($_POST['club_target_user_id'] ?? ''));
            $targetClubId = trim((string) ($_POST['club_target_club_id'] ?? ''));
            if ($targetUserId === '' || $targetClubId === '') {
                $errors[] = 'Usuario/club inválido para asignación.';
            } else {
                $payload = [
                    'p_player_id' => $targetUserId,
                    'p_logo_id' => $targetClubId,
                    'p_custom_image_url' => '',
                ];
                $result = api_request('POST', $supabaseUrl . '/rest/v1/rpc/set_player_profile_logo', $serviceRoleKey, $payload);
                if ($result['ok']) {
                    $success = 'Escudo de club asignado al usuario.';
                } else {
                    $errors[] = 'No se pudo asignar club: ' . $result['error'];
                }
            }
        }
    }
}

$users = [];
$notifications = [];
$profileLogos = [];
$uftPlayers = [];
$uftCards = [];
$uftCardTypes = [];
$uftEvents = [];
$uftPacks = [];
$uftMarketListings = [];
$uftSeasons = [];
$uftCountries = [];
$uftLeagues = [];
$uftClubs = [];
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

    $uftPlayersResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_players', $serviceRoleKey, []);
    if ($uftPlayersResult['ok'] && is_array($uftPlayersResult['data'])) {
        $uftPlayers = $uftPlayersResult['data'];
    }

    $uftCardsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_cards', $serviceRoleKey, []);
    if ($uftCardsResult['ok'] && is_array($uftCardsResult['data'])) {
        $uftCards = $uftCardsResult['data'];
    }

    $uftCardTypesResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_card_types', $serviceRoleKey, []);
    if ($uftCardTypesResult['ok'] && is_array($uftCardTypesResult['data'])) {
        $uftCardTypes = $uftCardTypesResult['data'];
    }

    $uftEventsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_events', $serviceRoleKey, []);
    if ($uftEventsResult['ok'] && is_array($uftEventsResult['data'])) {
        $uftEvents = $uftEventsResult['data'];
    }

    $uftPacksResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_packs', $serviceRoleKey, []);
    if ($uftPacksResult['ok'] && is_array($uftPacksResult['data'])) {
        $uftPacks = $uftPacksResult['data'];
    }

    $uftMarketResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_market_listings', $serviceRoleKey, []);
    if ($uftMarketResult['ok'] && is_array($uftMarketResult['data'])) {
        $uftMarketListings = $uftMarketResult['data'];
    }

    $uftSeasonsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_seasons', $serviceRoleKey, []);
    if ($uftSeasonsResult['ok'] && is_array($uftSeasonsResult['data'])) {
        $uftSeasons = $uftSeasonsResult['data'];
    }

    $countriesResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_countries', $serviceRoleKey, []);
    if ($countriesResult['ok'] && is_array($countriesResult['data'])) {
        $uftCountries = $countriesResult['data'];
    }
    $leaguesResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_leagues', $serviceRoleKey, []);
    if ($leaguesResult['ok'] && is_array($leaguesResult['data'])) {
        $uftLeagues = $leaguesResult['data'];
    }
    $clubsResult = api_request('POST', $supabaseUrl . '/rest/v1/rpc/list_uft_clubs', $serviceRoleKey, []);
    if ($clubsResult['ok'] && is_array($clubsResult['data'])) {
        $uftClubs = $clubsResult['data'];
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
        :root {
            --bg: #020617;
            --bg-soft: #0b1220;
            --panel: #0f172a;
            --panel-2: #111827;
            --line: #1e293b;
            --text: #e2e8f0;
            --muted: #94a3b8;
            --blue: #2563eb;
            --green: #16a34a;
            --red: #dc2626;
        }
        body {font-family: Inter, Arial, sans-serif; background:var(--bg); color:var(--text); margin:0; padding:20px;}
        .top {display:flex; justify-content:space-between; align-items:flex-start; gap:16px; flex-wrap:wrap; background:var(--panel); border:1px solid var(--line); border-radius:14px; padding:16px;}
        .top h1 {margin:0;}
        .top p {margin:8px 0 0 0; color:var(--muted);}
        .quick-nav {display:flex; flex-wrap:wrap; gap:8px; margin-top:12px;}
        .quick-nav a {text-decoration:none; color:var(--text); font-size:13px; background:var(--bg-soft); border:1px solid #334155; border-radius:999px; padding:6px 10px;}
        .stats {display:grid; gap:10px; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); margin-top:16px;}
        .stat {background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:12px;}
        .stat .label {font-size:12px; color:var(--muted);}
        .stat .value {font-size:24px; font-weight:700; margin-top:6px;}
        .panel {background:var(--panel); border:1px solid var(--line); border-radius:12px; padding:16px; margin-top:16px;}
        .panel h2 {margin:0 0 8px 0;}
        table {width:100%; border-collapse: collapse; margin-top:12px; font-size:14px;}
        th, td {padding:10px; border-bottom:1px solid #1e293b; text-align:left; vertical-align:top;}
        th {background:var(--panel-2);}
        .error {background:#7f1d1d; border:1px solid #ef4444; padding:10px; border-radius:8px; margin-top:10px;}
        .success {background:#14532d; border:1px solid #22c55e; padding:10px; border-radius:8px; margin-top:10px;}
        input[type="password"], input[type="text"], input[type="number"], textarea, select {padding:8px; border-radius:8px; border:1px solid #334155; background:var(--bg-soft); color:var(--text);}
        input[type="password"] {width:180px;}
        textarea {width:100%; box-sizing:border-box;}
        .btn {padding:8px 12px; border-radius:8px; border:none; cursor:pointer; color:#fff;}
        .btn-primary {background:var(--blue);}
        .btn-danger {background:var(--red);}
        .btn-secondary {background:#475569;}
        form.inline {display:inline-flex; gap:8px; align-items:center; flex-wrap:wrap;}
        code {background:var(--panel-2); padding:2px 6px; border-radius:6px;}
        .panel-grid {display:grid; gap:16px;}
        .field {display:grid; gap:6px;}
        .field label {font-size:12px; color:var(--muted);}
        @media (min-width: 980px) { .panel-grid {grid-template-columns:1fr 1fr;} }
    </style>
</head>
<body>
    <div class="top">
        <div>
            <h1 style="margin:0;">UFT 27 - Panel Admin</h1>
            <p>Administración centralizada del servidor y contenido UFT directamente desde Supabase.</p>
            <div class="quick-nav">
                <a href="#usuarios">Usuarios</a>
                <a href="#logos">Logos</a>
                <a href="#notificaciones">Notificaciones</a>
                <a href="#jugadores-uft">Jugadores UFT</a>
                <a href="#cartas-uft">Cartas UFT</a>
                <a href="#eventos-uft">Eventos UFT</a>
                <a href="#sobres-uft">Sobres UFT</a>
                <a href="#mercado-uft">Mercado UFT</a>
                <a href="#estructura-futbol">Países/Ligas/Clubes</a>
                <a href="#temporadas-uft">Temporadas UFT</a>
                <a href="market_admin.php">Página Mercado</a>
            </div>
        </div>
        <form method="post" class="inline">
            <button class="btn btn-secondary" name="logout" value="1" type="submit">Cerrar sesión</button>
        </form>
    </div>

    <div class="stats">
        <div class="stat">
            <div class="label">Usuarios registrados</div>
            <div class="value"><?php echo count($users); ?></div>
        </div>
        <div class="stat">
            <div class="label">Notificaciones activas</div>
            <div class="value"><?php echo count(array_filter($notifications, fn($n) => (bool) ($n['active'] ?? false))); ?></div>
        </div>
        <div class="stat">
            <div class="label">Cartas UFT</div>
            <div class="value"><?php echo count($uftCards); ?></div>
        </div>
        <div class="stat">
            <div class="label">Eventos UFT</div>
            <div class="value"><?php echo count($uftEvents); ?></div>
        </div>
    </div>

    <?php foreach ($errors as $error): ?>
        <div class="error"><?php echo h($error); ?></div>
    <?php endforeach; ?>
    <?php if ($success !== ''): ?>
        <div class="success"><?php echo h($success); ?></div>
    <?php endif; ?>

    <div class="panel" id="usuarios">
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


    <div class="panel" id="logos">
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

    <div class="panel" id="notificaciones">
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

    <div class="panel" id="jugadores-uft">
        <h2 style="margin-top:0;">Jugadores UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_player">
            <div class="field"><label>player_id (único)</label><input type="text" name="p_player_id" placeholder="ej: p_ronaldo01" required></div>
            <div class="field"><label>Nombre del jugador</label><input type="text" name="p_name" placeholder="Nombre" required></div>
            <div class="field"><label>Posición principal</label><input type="text" name="p_main_position" placeholder="POR/C/AI/AD/P" required></div>
            <div class="field"><label>Posiciones secundarias (JSON array)</label><input type="text" name="p_secondary_positions" placeholder='["AI","AD"]'></div>
            <div class="field"><label>URL foto de cara</label><input type="text" name="p_photo_face_url" placeholder="https://..."></div>
            <div class="field"><label>Pie dominante</label><input type="text" name="p_dominant_foot" placeholder="Derecho / Izquierdo"></div>
            <div class="field"><label>Nacionalidad</label><input type="text" name="p_nationality" placeholder="Argentina"></div>
            <div class="field"><label>Club (texto libre)</label><input type="text" name="p_club" placeholder="Club"></div>
            <div class="field"><label>Metadata adicional (JSON)</label><textarea name="p_metadata" rows="3" placeholder='{"height_cm":178}'></textarea></div>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar jugador UFT</button>
        </form>
        <table><thead><tr><th>player_id</th><th>Nombre</th><th>Pos</th><th>Club</th></tr></thead><tbody>
            <?php foreach ($uftPlayers as $p): ?>
                <tr><td><code><?php echo h((string)($p['player_id'] ?? '')); ?></code></td><td><?php echo h((string)($p['name'] ?? '')); ?></td><td><?php echo h((string)($p['main_position'] ?? '')); ?></td><td><?php echo h((string)($p['club'] ?? '')); ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="tipos-carta-uft">
        <h2 style="margin-top:0;">Tipos de carta UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_card_type">
            <input type="text" name="p_card_type_id" placeholder="card_type (ej: Base, Evento, TOTW)" required>
            <input type="text" name="p_card_type_display_name" placeholder="Nombre visible" required>
            <input type="text" name="p_card_type_rarity_default" placeholder="Rareza por defecto" value="Common">
            <label><input type="checkbox" name="p_card_type_active" checked> Activo</label>
            <textarea name="p_card_type_style" rows="3" placeholder='{"frame_color":"gold"}'></textarea>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar tipo de carta</button>
        </form>
        <table><thead><tr><th>card_type</th><th>Nombre</th><th>Rareza default</th><th>Activo</th></tr></thead><tbody>
            <?php foreach ($uftCardTypes as $t): ?>
                <tr><td><code><?php echo h((string)($t['card_type'] ?? '')); ?></code></td><td><?php echo h((string)($t['display_name'] ?? '')); ?></td><td><?php echo h((string)($t['rarity_default'] ?? '')); ?></td><td><?php echo ((bool)($t['active'] ?? false)) ? 'Sí' : 'No'; ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="cartas-uft">
        <h2 style="margin-top:0;">Cartas UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_card">
            <div class="field"><label>card_id (único)</label><input type="text" name="p_card_id" placeholder="ej: card_p_ronaldo01_base" required></div>
            <div class="field"><label>player_id relacionado</label><input type="text" name="p_card_player_id" placeholder="player_id" required></div>
            <div class="field"><label>Tipo de carta</label><input type="text" name="p_card_type" placeholder="Base / Evento / TOTW" required></div>
            <div class="field"><label>Rareza</label><input type="text" name="p_rarity" placeholder="Common / Rare / Epic" required></div>
            <div class="field"><label>OVR base</label><input type="number" name="p_ovr" min="1" max="120" value="75" required></div>
            <div class="field"><label>Nivel de evolución</label><input type="number" name="p_evolution_level" min="1" value="1" required></div>
            <div class="field"><label>Precio sugerido mercado</label><input type="number" name="p_suggested_price" min="0" value="0"></div>
            <div class="field"><label>URL frame de carta</label><input type="text" name="p_card_frame_url" placeholder="https://..."></div>
            <div class="field"><label>URL rostro</label><input type="text" name="p_face_url" placeholder="https://..."></div>
            <div class="field"><label>Ritmo (pace)</label><input type="number" name="p_pace" min="1" max="120" value="60"></div>
            <div class="field"><label>Regate (dribbling)</label><input type="number" name="p_dribbling" min="1" max="120" value="60"></div>
            <div class="field"><label>Pase (passing)</label><input type="number" name="p_passing" min="1" max="120" value="60"></div>
            <div class="field"><label>Tiro (shooting)</label><input type="number" name="p_shooting" min="1" max="120" value="60"></div>
            <div class="field"><label>Defensa (defense)</label><input type="number" name="p_defense" min="1" max="120" value="60"></div>
            <div class="field"><label>Físico (physical)</label><input type="number" name="p_physical" min="1" max="120" value="60"></div>
            <div class="field"><label>POR reflejos</label><input type="number" name="p_gk_reflejos" min="1" max="120" value="60"></div>
            <div class="field"><label>POR parada</label><input type="number" name="p_gk_parada" min="1" max="120" value="60"></div>
            <div class="field"><label>POR uno vs uno</label><input type="number" name="p_gk_uno_vs_uno" min="1" max="120" value="60"></div>
            <div class="field"><label>POR colocación</label><input type="number" name="p_gk_colocacion" min="1" max="120" value="60"></div>
            <div class="field"><label>POR juego con pies</label><input type="number" name="p_gk_juego_pies" min="1" max="120" value="60"></div>
            <div class="field"><label>POR físico</label><input type="number" name="p_gk_fisico" min="1" max="120" value="60"></div>
            <label><input type="checkbox" name="p_owned" checked> Poseída</label>
            <label><input type="checkbox" name="p_transferable" checked> Transferible</label>
            <label><input type="checkbox" name="p_locked"> Bloqueada</label>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar carta UFT</button>
        </form>
        <table><thead><tr><th>card_id</th><th>player_id</th><th>Tipo</th><th>Rareza</th><th>Evo</th><th>OVR</th><th>Poseída</th><th>Transferible</th><th>Precio</th></tr></thead><tbody>
            <?php foreach ($uftCards as $c): ?>
                <tr>
                    <td><code><?php echo h((string)($c['card_id'] ?? '')); ?></code></td>
                    <td><code><?php echo h((string)($c['player_id'] ?? '')); ?></code></td>
                    <td><?php echo h((string)($c['card_type'] ?? '')); ?></td>
                    <td><?php echo h((string)($c['rarity'] ?? '')); ?></td>
                    <td><?php echo h((string)($c['evolution_level'] ?? '1')); ?></td>
                    <td><?php echo h((string)($c['ovr'] ?? '')); ?></td>
                    <td><?php echo ((bool)($c['owned'] ?? false)) ? 'Sí' : 'No'; ?></td>
                    <td><?php echo ((bool)($c['transferable'] ?? false)) ? 'Sí' : 'No'; ?></td>
                    <td><?php echo h((string)($c['suggested_price'] ?? '0')); ?></td>
                </tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="eventos-uft">
        <h2 style="margin-top:0;">Eventos UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_event">
            <input type="text" name="p_event_id" placeholder="event_id" required>
            <input type="text" name="p_event_name" placeholder="Nombre evento" required>
            <textarea name="p_event_description" rows="3" placeholder="Descripción"></textarea>
            <input type="number" name="p_start_unix" placeholder="start_unix" required>
            <input type="number" name="p_end_unix" placeholder="end_unix" required>
            <input type="number" name="p_access_cost_coins" placeholder="Coste coins" value="0">
            <label><input type="checkbox" name="p_active" checked> Activo</label>
            <textarea name="p_rules" rows="3" placeholder="{}"></textarea>
            <textarea name="p_rewards" rows="3" placeholder="[]"></textarea>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar evento UFT</button>
        </form>
        <table><thead><tr><th>event_id</th><th>Nombre</th><th>Inicio</th><th>Fin</th><th>Activo</th></tr></thead><tbody>
            <?php foreach ($uftEvents as $e): ?>
                <tr><td><code><?php echo h((string)($e['event_id'] ?? '')); ?></code></td><td><?php echo h((string)($e['name'] ?? '')); ?></td><td><?php echo h((string)($e['start_unix'] ?? '')); ?></td><td><?php echo h((string)($e['end_unix'] ?? '')); ?></td><td><?php echo ((bool)($e['active'] ?? false)) ? 'Sí' : 'No'; ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="sobres-uft">
        <h2 style="margin-top:0;">Sobres UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_pack">
            <input type="text" name="p_pack_id" placeholder="pack_id" required>
            <input type="text" name="p_pack_name" placeholder="Nombre sobre" required>
            <input type="number" name="p_cost_coins" placeholder="Coste coins" value="0">
            <input type="number" name="p_cost_points" placeholder="Coste points" value="0">
            <input type="number" name="p_cards_count" placeholder="Cantidad de cartas" value="1" min="1" required>
            <input type="text" name="p_duplicate_policy" placeholder="Política duplicados (allow/no_dupes)" value="allow">
            <textarea name="p_pool" rows="3" placeholder="[]"></textarea>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar sobre UFT</button>
        </form>
        <table><thead><tr><th>pack_id</th><th>Nombre</th><th>Coins</th><th>Points</th><th>Cards</th></tr></thead><tbody>
            <?php foreach ($uftPacks as $p): ?>
                <tr><td><code><?php echo h((string)($p['pack_id'] ?? '')); ?></code></td><td><?php echo h((string)($p['name'] ?? '')); ?></td><td><?php echo h((string)($p['cost_coins'] ?? '')); ?></td><td><?php echo h((string)($p['cost_points'] ?? '')); ?></td><td><?php echo h((string)($p['cards_count'] ?? '')); ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="mercado-uft">
        <h2 style="margin-top:0;">Mercado UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_market_listing">
            <input type="text" name="p_listing_id" placeholder="listing_id" required>
            <input type="text" name="p_listing_card_id" placeholder="card_id" required>
            <input type="number" name="p_price" placeholder="Precio" value="100" min="0" required>
            <input type="text" name="p_seller" placeholder="Seller" value="npc_market">
            <label><input type="checkbox" name="p_listing_active" checked> Activo</label>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar publicación</button>
        </form>
        <table><thead><tr><th>listing_id</th><th>card_id</th><th>Precio</th><th>Seller</th><th>Activo</th></tr></thead><tbody>
            <?php foreach ($uftMarketListings as $m): ?>
                <tr><td><code><?php echo h((string)($m['listing_id'] ?? '')); ?></code></td><td><code><?php echo h((string)($m['card_id'] ?? '')); ?></code></td><td><?php echo h((string)($m['price'] ?? '')); ?></td><td><?php echo h((string)($m['seller'] ?? '')); ?></td><td><?php echo ((bool)($m['active'] ?? false)) ? 'Sí' : 'No'; ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>

    <div class="panel" id="estructura-futbol">
        <h2 style="margin-top:0;">Estructura de fútbol: Países → Ligas → Clubes</h2>
        <p style="color:#94a3b8; margin-top:0;">Esta estructura reemplaza la selección manual de escudo: ahora el perfil puede usar el escudo del club asignado al usuario.</p>

        <div class="panel-grid">
            <form method="post" style="display:grid; gap:8px;">
                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                <input type="hidden" name="action" value="upsert_country">
                <h3 style="margin:0;">Crear / editar país</h3>
                <div class="field"><label>ID país (UUID opcional para editar)</label><input type="text" name="country_id" placeholder="vacío para crear nuevo"></div>
                <div class="field"><label>Nombre del país</label><input type="text" name="country_name" required></div>
                <div class="field"><label>Código ISO (2-3 letras)</label><input type="text" name="country_iso_code" required></div>
                <div class="field"><label>Logo del país (URL)</label><input type="text" name="country_logo_url" placeholder="https://..."></div>
                <label><input type="checkbox" name="country_active" checked> Activo</label>
                <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar país</button>
            </form>

            <form method="post" style="display:grid; gap:8px;">
                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                <input type="hidden" name="action" value="upsert_league">
                <h3 style="margin:0;">Crear / editar liga</h3>
                <div class="field"><label>ID liga (UUID opcional para editar)</label><input type="text" name="league_id" placeholder="vacío para crear nueva"></div>
                <div class="field">
                    <label>País de la liga</label>
                    <select name="league_country_id" required>
                        <option value="">Selecciona país</option>
                        <?php foreach ($uftCountries as $country): ?>
                            <option value="<?php echo h((string) ($country['id'] ?? '')); ?>"><?php echo h((string) ($country['name'] ?? '')); ?> (<?php echo h((string) ($country['iso_code'] ?? '')); ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="field"><label>Nombre de la liga</label><input type="text" name="league_name" required></div>
                <div class="field"><label>Nivel de liga (1,2,3...)</label><input type="number" name="league_tier_level" min="1" value="1" required></div>
                <div class="field"><label>Logo de la liga (URL)</label><input type="text" name="league_logo_url" placeholder="https://..."></div>
                <label><input type="checkbox" name="league_active" checked> Activa</label>
                <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar liga</button>
            </form>
        </div>

        <div class="panel-grid" style="margin-top:12px;">
            <form method="post" style="display:grid; gap:8px;">
                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                <input type="hidden" name="action" value="upsert_club">
                <h3 style="margin:0;">Crear / editar club</h3>
                <div class="field"><label>ID club (UUID opcional para editar)</label><input type="text" name="club_id" placeholder="vacío para crear nuevo"></div>
                <div class="field">
                    <label>Liga del club</label>
                    <select name="club_league_id" required>
                        <option value="">Selecciona liga</option>
                        <?php foreach ($uftLeagues as $league): ?>
                            <option value="<?php echo h((string) ($league['id'] ?? '')); ?>"><?php echo h((string) ($league['country_name'] ?? '')); ?> · <?php echo h((string) ($league['name'] ?? '')); ?> (Nivel <?php echo h((string) ($league['tier_level'] ?? '1')); ?>)</option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="field"><label>Nombre del club</label><input type="text" name="club_name" required></div>
                <div class="field"><label>Logo del club (URL)</label><input type="text" name="club_logo_url" placeholder="https://..."></div>
                <label><input type="checkbox" name="club_active" checked> Activo</label>
                <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar club</button>
            </form>

            <form method="post" style="display:grid; gap:8px;">
                <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
                <input type="hidden" name="action" value="assign_user_club">
                <h3 style="margin:0;">Asignar club (escudo) a usuario</h3>
                <div class="field"><label>Usuario (UUID)</label><input type="text" name="club_target_user_id" required></div>
                <div class="field">
                    <label>Club para el perfil</label>
                    <select name="club_target_club_id" required>
                        <option value="">Selecciona club</option>
                        <?php foreach ($uftClubs as $club): ?>
                            <option value="<?php echo h((string) ($club['id'] ?? '')); ?>"><?php echo h((string) ($club['country_name'] ?? '')); ?> · <?php echo h((string) ($club['league_name'] ?? '')); ?> · <?php echo h((string) ($club['name'] ?? '')); ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <button class="btn btn-secondary" type="submit" style="width:max-content;">Asignar club</button>
            </form>
        </div>
    </div>

    <div class="panel" id="temporadas-uft">
        <h2 style="margin-top:0;">Temporadas UFT (Supabase)</h2>
        <form method="post" style="display:grid; gap:8px; max-width:1000px; margin-bottom:12px;">
            <input type="hidden" name="csrf_token" value="<?php echo h($_SESSION['csrf_token']); ?>">
            <input type="hidden" name="action" value="upsert_uft_season">
            <input type="text" name="p_season_id" placeholder="season_id" required>
            <input type="text" name="p_season_name" placeholder="Nombre temporada" required>
            <input type="number" name="p_season_start_unix" placeholder="start_unix" required>
            <input type="number" name="p_season_end_unix" placeholder="end_unix" required>
            <textarea name="p_levels" rows="4" placeholder="[]"></textarea>
            <button class="btn btn-primary" type="submit" style="width:max-content;">Guardar temporada UFT</button>
        </form>
        <table><thead><tr><th>season_id</th><th>Nombre</th><th>Inicio</th><th>Fin</th></tr></thead><tbody>
            <?php foreach ($uftSeasons as $s): ?>
                <tr><td><code><?php echo h((string)($s['season_id'] ?? '')); ?></code></td><td><?php echo h((string)($s['name'] ?? '')); ?></td><td><?php echo h((string)($s['start_unix'] ?? '')); ?></td><td><?php echo h((string)($s['end_unix'] ?? '')); ?></td></tr>
            <?php endforeach; ?>
        </tbody></table>
    </div>
</body>
</html>
