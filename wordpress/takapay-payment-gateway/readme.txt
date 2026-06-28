=== Takapay Payment Gateway ===
Contributors: takapay
Tags: payment, bKash, Nagad, Rocket, Bangladesh, mobile banking, webhook
Requires at least: 6.0
Tested up to: 6.9
Stable tag: 1.0.0
Requires PHP: 8.0
License: GPLv2 or later
License URI: https://www.gnu.org/licenses/gpl-2.0.html

Accept bKash, Nagad, and Rocket payments on your WordPress site. Verified automatically via the Takapay mobile app.

== Description ==

Takapay Payment Gateway allows you to accept payments from bKash, Nagad, and Rocket directly on your WordPress site. Payment notifications are captured by the Takapay Android app and forwarded to your site via a secure webhook.

= Features =

* Accept payments via bKash, Nagad, and Rocket
* Automatic payment verification via webhook
* Dedicated payment page with [takapay_payment_page] shortcode
* Secure HMAC-style webhook authentication
* Transaction history in the WordPress admin
* Multi-provider support
* Duplicate transaction detection
* Return URL redirection after successful payment

== Installation ==

1. Upload the `takapay-payment-gateway` folder to the `/wp-content/plugins/` directory.
2. Activate the plugin through the 'Plugins' menu in WordPress.
3. Go to the Takapay settings page to configure your webhook secret and payment instructions.
4. Add the `[takapay_payment_page]` shortcode to any page or post.
5. Configure the webhook URL and secret in your Takapay Android app.

== Usage ==

Add the shortcode to any page to display the payment form:

`[takapay_payment_page]`

To pre-set the amount:

`[takapay_payment_page amount="500"]`

Your checkout form can POST to the shortcode page with:
- `takapay_pg_amount` - the payment amount
- `takapay_pg_provider` - the provider ID (e.g. `bkash`, `nagad`, `rocket`)

Example:
`<form action="[payment page URL]" method="post">`
`  <input type="hidden" name="takapay_pg_amount" value="99.00">`
`  <input type="hidden" name="takapay_pg_provider" value="bkash">`
`  <button type="submit">Pay with bKash</button>`
`</form>`

After payment, customers enter their Transaction ID on the payment page. The page polls the server until the Takapay webhook confirms the transaction.

== Frequently Asked Questions ==

= Where do I get the Takapay app? =

Download the Takapay Android app from the Google Play Store.

= How does payment verification work? =

The Takapay app monitors incoming SMS notifications from bKash/Nagad/Rocket and forwards them to your webhook URL. Your WordPress site verifies the signature and stores the transaction.

== Changelog ==

= 1.0.0 =
* Initial release