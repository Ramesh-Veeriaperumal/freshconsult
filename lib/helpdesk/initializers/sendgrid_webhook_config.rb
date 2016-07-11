module SendgridWebhookConfig
	sendgrid_parse_webhook = (YAML::load_file(File.join(Rails.root, 'config', 'sendgrid_webhook_api.yml')))[Rails.env]
	sendgrid_parse_webhook.deep_symbolize_keys

	CONFIG = sendgrid_parse_webhook[:sendgrid]

	SENDGRID_API = CONFIG[:api]

	POST_URL = "https://%{full_domain}/email?verification_key=%{key}"
end