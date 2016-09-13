module SendgridWebhookConfig
	sendgrid_parse_webhook = (YAML::load_file(File.join(Rails.root, 'config', 'sendgrid_webhook_api.yml')))[Rails.env]

	CONFIG = sendgrid_parse_webhook['sendgrid']

	SENDGRID_API = CONFIG['api']

	POST_URL = "%{protocol}://%{full_domain}/email?verification_key=%{key}"
end
