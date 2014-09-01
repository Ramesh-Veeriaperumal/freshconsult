module AkismetConfig
	config = File.join(Rails.root, 'config', 'akismet.yml')

	KEY = (YAML::load_file config)[Rails.env]
end