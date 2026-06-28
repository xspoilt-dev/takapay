<?php

defined('ABSPATH') || exit;

add_action('admin_menu', 'takapay_pg_add_admin_menu');
add_action('admin_init', 'takapay_pg_register_settings');

function takapay_pg_add_admin_menu()
{
    add_menu_page(
        'Takapay Payments',
        'Takapay',
        'manage_options',
        'takapay-pg',
        'takapay_pg_render_settings_page',
        'dashicons-money-alt',
        80
    );

    add_submenu_page(
        'takapay-pg',
        'Transactions',
        'Transactions',
        'manage_options',
        'takapay-pg-transactions',
        'takapay_pg_render_transactions_page'
    );

    add_submenu_page(
        'takapay-pg',
        'Webhook Test',
        'Webhook Test',
        'manage_options',
        'takapay-pg-webhook-test',
        'takapay_pg_render_webhook_test_page'
    );
}

function takapay_pg_register_settings()
{
    register_setting('takapay_pg_settings', 'takapay_pg_secret');
    register_setting('takapay_pg_settings', 'takapay_pg_providers');
    register_setting('takapay_pg_settings', 'takapay_pg_provider_instructions');
    register_setting('takapay_pg_settings', 'takapay_pg_return_url');
    register_setting('takapay_pg_settings', 'takapay_pg_auto_verify');

    add_filter('pre_update_option_takapay_pg_providers', 'takapay_pg_sanitize_providers', 10, 2);
}

function takapay_pg_sanitize_providers($new_value, $old_value)
{
    if (!is_array($new_value)) {
        return $old_value;
    }
    $clean = [];
    foreach ($new_value as $item) {
        if (!empty($item['id']) && !empty($item['label'])) {
            $clean[] = [
                'id'     => sanitize_key($item['id']),
                'label'  => sanitize_text_field($item['label']),
                'number' => sanitize_text_field($item['number'] ?? ''),
            ];
        }
    }
    return $clean;
}

function takapay_pg_render_settings_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Unauthorized');
    }

    $secret       = get_option('takapay_pg_secret', '');
    $providers    = get_option('takapay_pg_providers', []);
    $instructions = get_option('takapay_pg_provider_instructions', []);
    $return_url   = get_option('takapay_pg_return_url', '');

    if (isset($_GET['regenerate_secret']) && check_admin_referer('takapay_pg_regenerate_secret')) {
        $secret = wp_generate_password(32, false);
        update_option('takapay_pg_secret', $secret);
        echo '<div class="notice notice-success is-dismissible"><p>Secret regenerated successfully.</p></div>';
    }

    if (isset($_POST['add_provider']) && check_admin_referer('takapay_pg_add_provider')) {
        $id = sanitize_key($_POST['provider_id'] ?? '');
        $label = sanitize_text_field($_POST['provider_label'] ?? '');
        if (!empty($id) && !empty($label)) {
            $providers[] = ['id' => $id, 'label' => $label, 'number' => ''];
            update_option('takapay_pg_providers', $providers);
            echo '<div class="notice notice-success is-dismissible"><p>Provider added.</p></div>';
        }
    }

    if (isset($_GET['remove_provider']) && check_admin_referer('takapay_pg_remove_provider')) {
        $remove_id = sanitize_key($_GET['remove_provider']);
        $providers = array_values(array_filter($providers, fn($p) => ($p['id'] ?? '') !== $remove_id));
        update_option('takapay_pg_providers', $providers);
        echo '<div class="notice notice-success is-dismissible"><p>Provider removed.</p></div>';
    }

    $webhook_url = rest_url('takapay/v1/webhook');

    $default_instructions = [
        'bkash'  => "Go to your bKash Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your bKash PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
        'nagad'  => "Go to your Nagad Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your Nagad PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
        'rocket' => "Go to your Rocket Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your Rocket PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
    ];
    ?>
    <div class="wrap">
        <h1>Takapay Payment Settings</h1>

        <form method="post" action="options.php">
            <?php settings_fields('takapay_pg_settings'); ?>

            <h2 style="margin-top: 1.5em;">Webhook</h2>
            <table class="form-table" role="presentation">
                <tr>
                    <th scope="row">Webhook URL</th>
                    <td>
                        <code style="font-size: 13px;"><?php echo esc_url($webhook_url); ?></code>
                        <button type="button" class="button button-small" onclick="navigator.clipboard.writeText('<?php echo esc_js($webhook_url); ?>')">Copy</button>
                        <p class="description">Enter this URL in the Takapay Android app as the webhook endpoint.</p>
                    </td>
                </tr>
                <tr>
                    <th scope="row">Webhook Secret</th>
                    <td>
                        <code style="font-size: 13px;"><?php echo esc_html($secret); ?></code>
                        <button type="button" class="button button-small" onclick="navigator.clipboard.writeText('<?php echo esc_js($secret); ?>')">Copy</button>
                        <a href="<?php echo esc_url(wp_nonce_url(add_query_arg('regenerate_secret', '1'), 'takapay_pg_regenerate_secret')); ?>" class="button button-secondary" onclick="return confirm('Regenerate the webhook secret? Existing integrations using the old secret will stop working.')">Regenerate</a>
                        <p class="description">Use this secret when configuring the webhook endpoint in the Takapay app.</p>
                    </td>
                </tr>
            </table>

            <h2 style="margin-top: 1.5em;">Payment Providers</h2>
            <table class="form-table" role="presentation">
                <tr>
                    <th scope="row">Configured Providers</th>
                    <td>
                        <?php if (empty($providers)): ?>
                            <p>No providers configured yet. Add one below.</p>
                        <?php else: ?>
                            <table class="widefat striped" style="max-width:600px;">
                                <thead>
                                    <tr>
                                        <th>ID</th>
                                        <th>Label</th>
                                        <th>Account Number</th>
                                        <th></th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <?php foreach ($providers as $i => $p):
                                        $pid = $p['id'] ?? '';
                                    ?>
                                    <tr>
                                        <td><code><?php echo esc_html($pid); ?></code></td>
                                        <td>
                                            <input type="hidden" name="takapay_pg_providers[<?php echo $i; ?>][id]" value="<?php echo esc_attr($pid); ?>">
                                            <input type="text" name="takapay_pg_providers[<?php echo $i; ?>][label]" value="<?php echo esc_attr($p['label'] ?? ''); ?>" style="width:100px;">
                                        </td>
                                        <td>
                                            <input type="text" name="takapay_pg_providers[<?php echo $i; ?>][number]" value="<?php echo esc_attr($p['number'] ?? ''); ?>" style="width:150px;font-family:monospace;" placeholder="018XXXXXXXX">
                                        </td>
                                        <td>
                                            <a href="<?php echo esc_url(wp_nonce_url(add_query_arg('remove_provider', $pid), 'takapay_pg_remove_provider')); ?>" class="button button-small button-link-delete" onclick="return confirm('Remove this provider?')">Remove</a>
                                        </td>
                                    </tr>
                                    <?php endforeach; ?>
                                </tbody>
                            </table>
                        <?php endif; ?>
                        <p class="description">Set the account number where customers should send payments for each provider.</p>
                    </td>
                </tr>

                <tr>
                    <th scope="row">Add Provider</th>
                    <td>
                        <form method="post" style="display:flex; gap:0.5em; align-items:center;">
                            <?php wp_nonce_field('takapay_pg_add_provider'); ?>
                            <input type="text" name="provider_id" placeholder="ID (e.g. bkash)" style="width:120px;" required>
                            <input type="text" name="provider_label" placeholder="Label (e.g. bKash)" style="width:120px;" required>
                            <input type="submit" name="add_provider" class="button button-secondary" value="Add Provider">
                        </form>
                        <p class="description">Add new payment providers. bKash, Nagad, and Rocket are pre-configured on activation.</p>
                    </td>
                </tr>
            </table>

            <h2 style="margin-top: 1.5em;">Provider Instructions</h2>
            <p>Customize the payment instructions shown to customers. Use <code>{number}</code> for the account number and <code>{amount}</code> for the payment amount.</p>
            <table class="form-table" role="presentation">
                <?php foreach ($providers as $p):
                    $pid    = $p['id'] ?? '';
                    $label  = $p['label'] ?? $pid;
                    $custom = $instructions[$pid] ?? '';
                    $default = $default_instructions[$pid] ?? "Send {amount} BDT to {number}.\n\nEnter the Transaction ID below and press Verify.";
                ?>
                <tr>
                    <th scope="row"><?php echo esc_html($label); ?> Instructions</th>
                    <td>
                        <textarea name="takapay_pg_provider_instructions[<?php echo esc_attr($pid); ?>]" rows="6" class="large-text" placeholder="<?php echo esc_attr($default); ?>"><?php echo esc_textarea($custom); ?></textarea>
                        <p class="description">Leave empty to use the default template. Placeholders: <code>{number}</code>, <code>{amount}</code>.</p>
                    </td>
                </tr>
                <?php endforeach; ?>
            </table>

            <h2 style="margin-top: 1.5em;">General</h2>
            <table class="form-table" role="presentation">
                <tr>
                    <th scope="row">Return URL</th>
                    <td>
                        <input type="url" name="takapay_pg_return_url" value="<?php echo esc_url($return_url); ?>" class="regular-text" placeholder="<?php echo esc_attr(home_url('/order-received')); ?>">
                        <p class="description">Redirect customers here after successful payment. The <code>takapay_tx</code> query parameter will contain the Transaction ID.</p>
                    </td>
                </tr>
            </table>

            <p class="submit">
                <input type="submit" class="button-primary" value="Save Settings">
            </p>
        </form>

        <hr>

        <h2>Shortcode</h2>
        <p>Place this shortcode on any page to display the payment flow:</p>
        <p><code>[takapay_payment_page amount="500"]</code></p>
        <p>If your checkout form POSTs to this page, include <code>takapay_pg_amount</code> and <code>takapay_pg_provider</code> in the POST body.</p>
        <p>Example form action:</p>
        <pre style="background:#f5f5f5;padding:1em;border-radius:4px;">&lt;form action="&lt;?php echo esc_url(get_permalink($payment_page_id)); ?&gt;" method="post"&gt;
    &lt;input type="hidden" name="takapay_pg_amount" value="99.00"&gt;
    &lt;input type="hidden" name="takapay_pg_provider" value="bkash"&gt;
    &lt;button type="submit"&gt;Pay with bKash&lt;/button&gt;
&lt;/form&gt;</pre>
        <p>You can also let the plugin show a provider selection form by simply visiting the shortcode page without POST data.</p>
    </div>
    <?php
}

function takapay_pg_render_transactions_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Unauthorized');
    }

    $limit  = 50;
    $page   = isset($_GET['paged']) ? max(1, intval($_GET['paged'])) : 1;
    $offset = ($page - 1) * $limit;

    $transactions = takapay_pg_get_transactions($limit, $offset);
    $total        = takapay_pg_get_transaction_count();
    $total_amount = takapay_pg_get_total_amount();
    $pages        = ceil($total / $limit);
    ?>
    <div class="wrap">
        <h1>Takapay Transactions</h1>

        <div style="display: flex; gap: 1em; margin-bottom: 1.5em;">
            <div style="background: #f0f6fc; padding: 0.8em 1.2em; border-radius: 6px; border: 1px solid #c5d9ed;">
                <strong>Total Transactions:</strong> <?php echo number_format($total); ?>
            </div>
            <div style="background: #f0f6fc; padding: 0.8em 1.2em; border-radius: 6px; border: 1px solid #c5d9ed;">
                <strong>Total Amount:</strong> <?php echo number_format($total_amount, 2); ?> BDT
            </div>
        </div>

        <table class="wp-list-table widefat fixed striped">
            <thead>
                <tr>
                    <th>TrxID</th>
                    <th>Provider</th>
                    <th>Amount</th>
                    <th>From</th>
                    <th>Received At</th>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($transactions)): ?>
                    <tr><td colspan="5">No transactions yet.</td></tr>
                <?php else: ?>
                    <?php foreach ($transactions as $tx): ?>
                        <tr>
                            <td><code><?php echo esc_html($tx['trx_id']); ?></code></td>
                            <td><?php echo esc_html($tx['sender']); ?></td>
                            <td><?php echo esc_html(number_format($tx['amount'], 2)); ?> BDT</td>
                            <td><?php echo esc_html($tx['from_number']); ?></td>
                            <td><?php echo esc_html($tx['received_at']); ?></td>
                        </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>

        <?php if ($pages > 1): ?>
            <div class="tablenav" style="margin-top: 1em;">
                <div class="tablenav-pages">
                    <?php
                    echo paginate_links([
                        'base'      => add_query_arg('paged', '%#%'),
                        'format'    => '',
                        'prev_text' => '&laquo;',
                        'next_text' => '&raquo;',
                        'total'     => $pages,
                        'current'   => $page,
                    ]);
                    ?>
                </div>
            </div>
        <?php endif; ?>
    </div>
    <?php
}

function takapay_pg_render_webhook_test_page()
{
    if (!current_user_can('manage_options')) {
        wp_die('Unauthorized');
    }

    $test_result = '';

    if (isset($_POST['test_webhook']) && check_admin_referer('takapay_pg_webhook_test')) {
        $secret = get_option('takapay_pg_secret', '');
        $url    = rest_url('takapay/v1/webhook');

        $response = wp_remote_post($url, [
            'headers' => [
                'Content-Type'      => 'application/json',
                'X-Webhook-Secret' => $secret,
            ],
            'body'    => json_encode([
                'test'   => 'connection',
                'secret' => $secret,
            ]),
            'timeout' => 10,
        ]);

        if (is_wp_error($response)) {
            $test_result = '<div class="notice notice-error"><p>Connection test failed: ' . esc_html($response->get_error_message()) . '</p></div>';
        } else {
            $code = wp_remote_retrieve_response_code($response);
            $body = wp_remote_retrieve_body($response);
            if ($code >= 200 && $code < 300) {
                $test_result = '<div class="notice notice-success"><p>Connection successful! HTTP ' . $code . ' &mdash; Response: ' . esc_html($body) . '</p></div>';
            } else {
                $test_result = '<div class="notice notice-error"><p>Connection failed. HTTP ' . $code . ' &mdash; Response: ' . esc_html($body) . '</p></div>';
            }
        }
    }

    $secret = get_option('takapay_pg_secret', '');
    ?>
    <div class="wrap">
        <h1>Webhook Test</h1>
        <p>Use this page to verify that your webhook endpoint is working correctly. It sends a connection test payload to your own server.</p>

        <?php echo $test_result; ?>

        <form method="post">
            <?php wp_nonce_field('takapay_pg_webhook_test'); ?>
            <table class="form-table">
                <tr>
                    <th scope="row">Webhook URL</th>
                    <td><code><?php echo esc_url(rest_url('takapay/v1/webhook')); ?></code></td>
                </tr>
                <tr>
                    <th scope="row">Secret</th>
                    <td><code><?php echo esc_html($secret); ?></code></td>
                </tr>
            </table>
            <p class="submit">
                <input type="submit" name="test_webhook" class="button-primary" value="Test Connection">
            </p>
        </form>

        <hr>

        <h3>Manual Test via cURL</h3>
        <p>You can also test from the command line:</p>
        <pre style="background: #f5f5f5; padding: 1em; border-radius: 4px; overflow-x: auto;">curl -X POST <?php echo esc_url(rest_url('takapay/v1/webhook')); ?> \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: <?php echo esc_attr($secret); ?>" \
  -d '{"test":"connection","secret":"<?php echo esc_attr($secret); ?>"}'</pre>

        <h3>Simulate a Real Transaction</h3>
        <p>Use this cURL command to simulate a payment notification:</p>
        <pre style="background: #f5f5f5; padding: 1em; border-radius: 4px; overflow-x: auto;">curl -X POST <?php echo esc_url(rest_url('takapay/v1/webhook')); ?> \
  -H "Content-Type: application/json" \
  -H "X-Webhook-Secret: <?php echo esc_attr($secret); ?>" \
  -d '{
    "sender": "bKash",
    "amount": "500.00",
    "trx_id": "TEST<?php echo esc_attr(wp_generate_password(6, false)); ?>",
    "from": "01712345678",
    "raw_body": "bKash Cash In 500.00 TK from 01712345678 received.",
    "timestamp": "<?php echo esc_attr(gmdate('Y-m-d\TH:i:s\Z')); ?>",
    "secret": "<?php echo esc_attr($secret); ?>"
  }'</pre>
    </div>
    <?php
}