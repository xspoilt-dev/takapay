<?php
/**
 * Plugin Name: Takapay Payment Gateway
 * Plugin URI: https://takapay.app
 * Description: Accept payments via bKash, Nagad, and Rocket through the Takapay mobile app. Verifies transactions via webhook and displays payment instructions on your site.
 * Version: 1.0.0
 * Requires at least: 6.0
 * Requires PHP: 8.0
 * Author: Takapay
 * License: GPL v2 or later
 * Text Domain: takapay-pg
 */

defined('ABSPATH') || exit;

define('TAKAPAY_PG_VERSION', '1.0.0');
define('TAKAPAY_PG_FILE', __FILE__);
define('TAKAPAY_PG_PATH', plugin_dir_path(__FILE__));
define('TAKAPAY_PG_URL', plugin_dir_url(__FILE__));

define('TAKAPAY_PG_DB_VERSION', '1');

register_activation_hook(__FILE__, 'takapay_pg_activate');
register_deactivation_hook(__FILE__, 'takapay_pg_deactivate');

function takapay_pg_activate()
{
    require_once TAKAPAY_PG_PATH . 'includes/database.php';
    takapay_pg_create_tables();

    if (!get_option('takapay_pg_db_version')) {
        add_option('takapay_pg_db_version', TAKAPAY_PG_DB_VERSION);
    }

    if (!get_option('takapay_pg_secret')) {
        add_option('takapay_pg_secret', wp_generate_password(32, false));
    }

    if (!get_option('takapay_pg_providers')) {
        add_option('takapay_pg_providers', [
            ['id' => 'bkash', 'label' => 'bKash', 'number' => ''],
            ['id' => 'nagad', 'label' => 'Nagad', 'number' => ''],
            ['id' => 'rocket', 'label' => 'Rocket', 'number' => ''],
        ]);
    }

    if (!get_option('takapay_pg_auto_verify')) {
        add_option('takapay_pg_auto_verify', 1);
    }

    flush_rewrite_rules();
}

function takapay_pg_deactivate()
{
    flush_rewrite_rules();
}

require_once TAKAPAY_PG_PATH . 'includes/database.php';
require_once TAKAPAY_PG_PATH . 'includes/webhook-handler.php';
require_once TAKAPAY_PG_PATH . 'includes/shortcodes.php';

if (is_admin()) {
    require_once TAKAPAY_PG_PATH . 'admin/admin-settings.php';
}