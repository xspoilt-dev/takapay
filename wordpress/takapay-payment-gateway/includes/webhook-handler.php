<?php

defined('ABSPATH') || exit;

add_action('rest_api_init', 'takapay_pg_register_webhook_route');
add_action('rest_api_init', 'takapay_pg_register_verify_route');

function takapay_pg_register_webhook_route()
{
    register_rest_route('takapay/v1', '/webhook', [
        'methods'             => 'POST',
        'callback'            => 'takapay_pg_handle_webhook',
        'permission_callback' => '__return_true',
    ]);
}

function takapay_pg_register_verify_route()
{
    register_rest_route('takapay/v1', '/verify-transaction', [
        'methods'             => 'POST',
        'callback'            => 'takapay_pg_handle_verify',
        'permission_callback' => '__return_true',
    ]);
}

function takapay_pg_handle_webhook(WP_REST_Request $request)
{
    $secret = get_option('takapay_pg_secret', '');

    $secretHeader = $request->get_header('x-webhook-secret');
    $body         = $request->get_json_params();
    $secretBody   = $body['secret'] ?? '';

    if ($secretHeader !== $secret && $secretBody !== $secret) {
        return new WP_REST_Response(
            ['error' => 'Unauthorized payload signature'],
            401
        );
    }

    if (isset($body['test']) && $body['test'] === 'connection') {
        return new WP_REST_Response(['status' => 'connected'], 200);
    }

    $sender   = sanitize_text_field($body['sender'] ?? '');
    $amount   = sanitize_text_field($body['amount'] ?? '');
    $trxId    = sanitize_text_field($body['trx_id'] ?? '');
    $from     = sanitize_text_field($body['from'] ?? 'Unknown');
    $rawBody  = sanitize_textarea_field($body['raw_body'] ?? '');
    $ts       = sanitize_text_field($body['timestamp'] ?? '');

    if (empty($trxId) || empty($sender) || empty($amount)) {
        return new WP_REST_Response(
            ['error' => 'Missing required fields: trx_id, sender, amount'],
            400
        );
    }

    if (takapay_pg_transaction_exists($trxId)) {
        return new WP_REST_Response(
            ['success' => true, 'message' => 'Duplicate transaction ignored'],
            200
        );
    }

    $inserted = takapay_pg_insert_transaction([
        'trx_id'    => $trxId,
        'sender'    => $sender,
        'amount'    => $amount,
        'from'      => $from,
        'raw_body'  => $rawBody,
        'timestamp' => $ts,
    ]);

    if ($inserted === false) {
        return new WP_REST_Response(
            ['error' => 'Failed to store transaction'],
            500
        );
    }

    do_action('takapay_pg_payment_received', $trxId, $sender, $amount, $from);

    return new WP_REST_Response(
        ['success' => true, 'message' => 'Transaction processed'],
        200
    );
}

function takapay_pg_handle_verify(WP_REST_Request $request)
{
    $body  = $request->get_json_params();
    $trxId = sanitize_text_field($body['trx_id'] ?? '');

    if (empty($trxId)) {
        return new WP_REST_Response(
            ['verified' => false, 'error' => 'Missing trx_id'],
            400
        );
    }

    $tx = takapay_pg_get_transaction_by_trx_id($trxId);

    if ($tx) {
        return new WP_REST_Response([
            'verified' => true,
            'sender'   => $tx['sender'],
            'amount'   => $tx['amount'],
            'from'     => $tx['from_number'],
        ], 200);
    }

    return new WP_REST_Response(['verified' => false], 200);
}