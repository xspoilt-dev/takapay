<?php

defined('ABSPATH') || exit;

// Add rewrite rule on init
add_action('init', 'takapay_pg_add_payment_route');
function takapay_pg_add_payment_route()
{
    add_rewrite_rule('^takapay-pay/?$', 'index.php?takapay_pay=1', 'top');
}

// Register query var
add_filter('query_vars', 'takapay_pg_payment_query_vars');
function takapay_pg_payment_query_vars($vars)
{
    $vars[] = 'takapay_pay';
    return $vars;
}

// Handle the request on template_redirect before canonical redirects or theme loads
add_action('template_redirect', 'takapay_pg_handle_payment_route', 1);
function takapay_pg_handle_payment_route()
{
    $is_payment_page = false;

    if (get_query_var('takapay_pay')) {
        $is_payment_page = true;
    } else {
        // Fallback for when rewrite rules aren't flushed or pretty permalinks are disabled
        $request_uri = $_SERVER['REQUEST_URI'] ?? '';
        $path = parse_url($request_uri, PHP_URL_PATH);
        $path = trim($path, '/');
        
        $home_path = parse_url(home_url(), PHP_URL_PATH);
        $home_path = trim($home_path, '/');
        
        $relative_path = $path;
        if (!empty($home_path) && strpos($path, $home_path) === 0) {
            $relative_path = substr($path, strlen($home_path));
            $relative_path = trim($relative_path, '/');
        }
        
        if ($relative_path === 'takapay-pay') {
            $is_payment_page = true;
        }
    }

    if ($is_payment_page) {
        // Prevent caching
        nocache_headers();
        
        // Pass GET/POST parameters to the shortcode function
        $atts = [
            'amount' => isset($_GET['amount']) ? sanitize_text_field($_GET['amount']) : '',
            'title'  => isset($_GET['title']) ? sanitize_text_field($_GET['title']) : '',
        ];
        
        get_header();
        
        echo '<div class="takapay-pg-custom-route-container" style="padding: 40px 20px; min-height: 60vh; background: #fafafa; display: flex; align-items: center; justify-content: center; box-sizing: border-box;">';
        echo takapay_pg_render_payment_page($atts);
        echo '</div>';
        
        get_footer();
        exit;
    }
}
