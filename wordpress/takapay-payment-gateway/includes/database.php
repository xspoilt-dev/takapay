<?php

defined('ABSPATH') || exit;

function takapay_pg_create_tables()
{
    global $wpdb;

    $charset = $wpdb->get_charset_collate();

    $sql = "CREATE TABLE IF NOT EXISTS {$wpdb->prefix}takapay_transactions (
        id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
        trx_id VARCHAR(64) NOT NULL,
        sender VARCHAR(32) NOT NULL,
        amount DECIMAL(12,2) NOT NULL,
        from_number VARCHAR(32) NOT NULL DEFAULT 'Unknown',
        raw_body TEXT,
        received_at DATETIME NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY uk_trx_id (trx_id),
        INDEX idx_received_at (received_at),
        INDEX idx_sender (sender)
    ) $charset;";

    require_once ABSPATH . 'wp-admin/includes/upgrade.php';
    dbDelta($sql);
}

function takapay_pg_transaction_exists($trx_id)
{
    global $wpdb;
    return (bool) $wpdb->get_var($wpdb->prepare(
        "SELECT COUNT(*) FROM {$wpdb->prefix}takapay_transactions WHERE trx_id = %s",
        $trx_id
    ));
}

function takapay_pg_insert_transaction($data)
{
    global $wpdb;

    return $wpdb->insert(
        "{$wpdb->prefix}takapay_transactions",
        [
            'trx_id'      => $data['trx_id'],
            'sender'      => $data['sender'],
            'amount'      => $data['amount'],
            'from_number' => $data['from'],
            'raw_body'    => $data['raw_body'] ?? '',
            'received_at' => $data['timestamp'] ?? current_time('mysql'),
        ],
        ['%s', '%s', '%f', '%s', '%s', '%s']
    );
}

function takapay_pg_get_transactions($limit = 50, $offset = 0)
{
    global $wpdb;

    return $wpdb->get_results(
        $wpdb->prepare(
            "SELECT * FROM {$wpdb->prefix}takapay_transactions ORDER BY created_at DESC LIMIT %d OFFSET %d",
            $limit,
            $offset
        ),
        ARRAY_A
    );
}

function takapay_pg_get_transaction_count()
{
    global $wpdb;
    return (int) $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}takapay_transactions");
}

function takapay_pg_get_total_amount()
{
    global $wpdb;
    return (float) $wpdb->get_var("SELECT COALESCE(SUM(amount), 0) FROM {$wpdb->prefix}takapay_transactions");
}

function takapay_pg_get_transaction_by_trx_id($trx_id)
{
    global $wpdb;
    return $wpdb->get_row($wpdb->prepare(
        "SELECT * FROM {$wpdb->prefix}takapay_transactions WHERE trx_id = %s",
        $trx_id
    ), ARRAY_A);
}