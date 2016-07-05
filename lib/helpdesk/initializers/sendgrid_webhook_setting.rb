module SendgridWebhookSetting
	config = (YAML::load_file(File.join(Rails.root, 'config', 'sendgrid_webhook_api.yml')))

	sendgrid_api = config['sendgrid'][Rails.env]

	post_url = "https://%{full_domain}/email?verification_key=%{key}"
end