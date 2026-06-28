<?php

defined('ABSPATH') || exit;

add_shortcode('takapay_payment_page', 'takapay_pg_render_payment_page');

function takapay_pg_get_provider_label($id)
{
    $labels = [
        'bkash'  => 'bKash',
        'nagad'  => 'Nagad',
        'rocket' => 'Rocket',
    ];
    return $labels[$id] ?? ucfirst($id);
}

function takapay_pg_get_provider_config($id)
{
    $configs = get_option('takapay_pg_providers', []);
    foreach ($configs as $c) {
        if (($c['id'] ?? '') === $id) {
            return $c;
        }
    }
    return null;
}

function takapay_pg_get_default_instructions($provider_id, $number, $amount)
{
    $amount_fmt = number_format($amount, 2);

    $templates = [
        'bkash' => "Go to your bKash Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your bKash PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
        'nagad' => "Go to your Nagad Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your Nagad PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
        'rocket' => "Go to your Rocket Mobile App.\n\nChoose \"Send Money\"\n\nEnter the Number: {number}\n\nEnter the Amount: {amount} BDT\n\nNow enter your Rocket PIN to confirm.\n\nPut the Transaction ID in the box below and press Verify.",
    ];

    $template = $templates[$provider_id] ?? "Send {amount} BDT to {number}.\n\nEnter the Transaction ID below and press Verify.";

    $custom = get_option('takapay_pg_provider_instructions', []);
    if (!empty($custom[$provider_id])) {
        $template = $custom[$provider_id];
    }

    return str_replace(['{number}', '{amount}'], [$number, $amount_fmt], $template);
}

function takapay_pg_render_payment_page($atts)
{
    $atts = shortcode_atts([
        'amount'  => '',
        'title'   => '',
    ], $atts, 'takapay_payment_page');

    $amount = !empty($_POST['takapay_pg_amount'])
        ? floatval($_POST['takapay_pg_amount'])
        : (!empty($atts['amount']) ? floatval($atts['amount']) : 0);

    $provider = !empty($_POST['takapay_pg_provider'])
        ? sanitize_key($_POST['takapay_pg_provider'])
        : '';

    $trx_id = !empty($_POST['takapay_pg_trx_id'])
        ? sanitize_text_field($_POST['takapay_pg_trx_id'])
        : '';

    $verifying = !empty($trx_id);

    if (!empty($provider) && $amount > 0) {
        return takapay_pg_render_instructions($provider, $amount, $trx_id, $verifying);
    }

    return takapay_pg_render_checkout_form($amount, $atts['title']);
}

function takapay_pg_render_checkout_form($preset_amount, $title)
{
    $providers = get_option('takapay_pg_providers', []);

    ob_start();
    ?>
    <div class="takapay-pg-wrap">
        <style>
            .takapay-pg-wrap { max-width: 480px; margin: 0 auto; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
            .takapay-pg-wrap h2 { margin-bottom: 1em; }
            .takapay-pg-form .takapay-pg-field { margin-bottom: 1.25em; }
            .takapay-pg-form label { display: block; font-weight: 600; margin-bottom: 0.4em; color: #333; }
            .takapay-pg-form select, .takapay-pg-form input[type="number"] {
                width: 100%; padding: 0.6em 0.8em; font-size: 1em;
                border: 1px solid #ccc; border-radius: 6px; box-sizing: border-box;
            }
            .takapay-pg-form .takapay-pg-btn {
                display: block; width: 100%; padding: 0.8em;
                background: #2271b1; color: #fff; border: none; border-radius: 6px;
                font-size: 1.05em; font-weight: 600; cursor: pointer;
            }
            .takapay-pg-form .takapay-pg-btn:hover { background: #135e96; }
        </style>
        <h2><?php echo $title ? esc_html($title) : 'Select Payment Method'; ?></h2>
        <form class="takapay-pg-form" method="post">
            <div class="takapay-pg-field">
                <label for="takapay_pg_provider">Payment Method</label>
                <select name="takapay_pg_provider" id="takapay_pg_provider" required>
                    <option value="">— Select —</option>
                    <?php foreach ($providers as $p): ?>
                        <option value="<?php echo esc_attr($p['id']); ?>">
                            <?php echo esc_html($p['label']); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </div>
            <?php if ($preset_amount <= 0): ?>
                <div class="takapay-pg-field">
                    <label for="takapay_pg_amount">Amount (BDT)</label>
                    <input type="number" name="takapay_pg_amount" id="takapay_pg_amount" step="0.01" min="1" required>
                </div>
            <?php else: ?>
                <input type="hidden" name="takapay_pg_amount" value="<?php echo esc_attr($preset_amount); ?>">
                <div class="takapay-pg-field" style="font-size: 1.15em; padding: 0.6em 0;">
                    <strong>Amount:</strong> <?php echo esc_html(number_format($preset_amount, 2)); ?> BDT
                </div>
            <?php endif; ?>
            <button type="submit" class="takapay-pg-btn">Continue to Payment</button>
        </form>
    </div>
    <?php
    return ob_get_clean();
}

function takapay_pg_render_instructions($provider, $amount, $trx_id, $verifying)
{
    $config = takapay_pg_get_provider_config($provider);
    $number = $config['number'] ?? '';
    $label  = $config['label'] ?? takapay_pg_get_provider_label($provider);
    $instructions = takapay_pg_get_default_instructions($provider, $number, $amount);

    $verify_url = rest_url('takapay/v1/verify-transaction');

    ob_start();
    ?>
    <div class="takapay-pg-wrap">
        <style>
            .takapay-pg-wrap { max-width: 520px; margin: 0 auto; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
            .takapay-pg-card { background: #fff; border: 1px solid #e0e0e0; border-radius: 10px; padding: 1.5em; }
            .takapay-pg-amount { font-size: 2em; font-weight: 700; color: #2271b1; margin: 0.3em 0 0.6em; }
            .takapay-pg-provider-badge {
                display: inline-block; background: #e8f0fe; color: #2271b1;
                padding: 0.3em 0.9em; border-radius: 20px; font-weight: 600; font-size: 0.9em;
            }
            .takapay-pg-instructions {
                background: #f8f9fa; border-left: 4px solid #2271b1;
                padding: 1em 1.25em; border-radius: 4px; margin: 1em 0;
                white-space: pre-line; line-height: 1.7;
            }
            .takapay-pg-number-display {
                text-align: center; font-size: 1.3em; font-weight: 700;
                font-family: 'Courier New', monospace; background: #fff;
                padding: 0.6em; border: 2px dashed #2271b1; border-radius: 8px;
                margin: 0.8em 0;
            }
            .takapay-pg-field { margin-bottom: 1em; }
            .takapay-pg-field label { display: block; font-weight: 600; margin-bottom: 0.3em; color: #333; }
            .takapay-pg-field input[type="text"] {
                width: 100%; padding: 0.7em 0.8em; font-size: 1em;
                border: 1px solid #ccc; border-radius: 6px; box-sizing: border-box;
                font-family: 'Courier New', monospace;
            }
            .takapay-pg-btn {
                display: block; width: 100%; padding: 0.8em;
                background: #2271b1; color: #fff; border: none; border-radius: 6px;
                font-size: 1.05em; font-weight: 600; cursor: pointer;
            }
            .takapay-pg-btn:hover { background: #135e96; }
            .takapay-pg-btn:disabled { opacity: 0.6; cursor: not-allowed; }

            .takapay-pg-status { text-align: center; padding: 1.5em; }
            .takapay-pg-spinner {
                border: 4px solid #e0e0e0; border-top: 4px solid #2271b1;
                border-radius: 50%; width: 40px; height: 40px;
                animation: takapay-spin 0.8s linear infinite; margin: 0 auto 1em;
            }
            @keyframes takapay-spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

            .takapay-pg-success { text-align: center; padding: 1.5em; }
            .takapay-pg-success .checkmark {
                font-size: 3.5em; color: #46b450; width: 70px; height: 70px;
                line-height: 70px; border-radius: 50%; background: #ecf7ed;
                margin: 0 auto 0.5em;
            }
            .takapay-pg-success h2 { color: #46b450; margin: 0.3em 0; }
            .takapay-pg-success .tx-id {
                font-family: monospace; background: #f5f5f5;
                padding: 0.4em 0.8em; border-radius: 4px; display: inline-block; margin-top: 0.5em;
            }
            .takapay-pg-note {
                background: #fff8e5; border-left: 4px solid #f0b849;
                padding: 0.7em 1em; border-radius: 4px; font-size: 0.85em; color: #664d00; margin-top: 1em;
            }
        </style>

        <?php if ($verifying): ?>
            <div class="takapay-pg-card" id="takapay-pg-verifying">
                <div class="takapay-pg-status">
                    <div class="takapay-pg-spinner"></div>
                    <h3>Verifying Payment</h3>
                    <p style="color: #666;">Waiting for transaction <strong><?php echo esc_html($trx_id); ?></strong> to be confirmed via the Takapay app.</p>
                    <p style="color: #999; font-size: 0.85em;">This page refreshes automatically. Do not close it.</p>
                </div>

                <div class="takapay-pg-success" id="takapay-pg-success" style="display:none;">
                    <div class="checkmark">&#10004;</div>
                    <h2>Payment Received!</h2>
                    <p>Your payment of <strong><?php echo esc_html(number_format($amount, 2)); ?> BDT</strong> via <?php echo esc_html($label); ?> has been verified successfully.</p>
                    <div class="tx-id">TrxID: <?php echo esc_html($trx_id); ?></div>
                </div>
            </div>

            <script>
            (function() {
                var trxId = '<?php echo esc_js($trx_id); ?>';
                var verifyUrl = '<?php echo esc_js($verify_url); ?>';
                var pollInterval = 3000;
                var maxAttempts = 60;
                var attempts = 0;
                var verified = false;

                function poll() {
                    if (verified || attempts >= maxAttempts) return;
                    attempts++;

                    fetch(verifyUrl, {
                        method: 'POST',
                        headers: { 'Content-Type': 'application/json' },
                        body: JSON.stringify({ trx_id: trxId })
                    })
                    .then(function(r) { return r.json(); })
                    .then(function(data) {
                        if (data.verified) {
                            verified = true;
                            document.getElementById('takapay-pg-verifying').querySelector('.takapay-pg-status').style.display = 'none';
                            document.getElementById('takapay-pg-success').style.display = 'block';
                            <?php if (!empty(get_option('takapay_pg_return_url', ''))): ?>
                            setTimeout(function() {
                                var sep = '<?php echo esc_js(get_option('takapay_pg_return_url', '')); ?>'.indexOf('?') === -1 ? '?' : '&';
                                window.location.href = '<?php echo esc_js(get_option('takapay_pg_return_url', '')); ?>' + sep + 'takapay_tx=' + encodeURIComponent(trxId);
                            }, 3000);
                            <?php endif; ?>
                        }
                    })
                    .catch(function() {})
                    .then(function() {
                        if (!verified && attempts < maxAttempts) {
                            setTimeout(poll, pollInterval);
                        }
                    });
                }

                setTimeout(poll, pollInterval);
            })();
            </script>

        <?php else: ?>
            <div class="takapay-pg-card">
                <div style="display:flex; align-items:center; justify-content:space-between;">
                    <span class="takapay-pg-provider-badge"><?php echo esc_html($label); ?></span>
                </div>
                <div class="takapay-pg-amount"><?php echo esc_html(number_format($amount, 2)); ?> BDT</div>

                <?php if (!empty($number)): ?>
                    <div class="takapay-pg-number-display"><?php echo esc_html($number); ?></div>
                <?php endif; ?>

                <div class="takapay-pg-instructions"><?php echo esc_html($instructions); ?></div>

                <form method="post" class="takapay-pg-form" id="takapay-pg-verify-form">
                    <input type="hidden" name="takapay_pg_amount" value="<?php echo esc_attr($amount); ?>">
                    <input type="hidden" name="takapay_pg_provider" value="<?php echo esc_attr($provider); ?>">
                    <div class="takapay-pg-field">
                        <label for="takapay_pg_trx_id">Transaction ID (TrxID)</label>
                        <input type="text" name="takapay_pg_trx_id" id="takapay_pg_trx_id"
                               placeholder="e.g. 8K5L9M2N" required
                               pattern="[A-Za-z0-9]+" title="Alphanumeric transaction ID">
                    </div>
                    <button type="submit" class="takapay-pg-btn">Verify Payment</button>
                </form>

                <div class="takapay-pg-note">
                    After sending the payment, you will receive an SMS with a Transaction ID (TrxID).
                    Enter it above to verify your payment automatically.
                </div>
            </div>
        <?php endif; ?>
    </div>
    <?php
    return ob_get_clean();
}