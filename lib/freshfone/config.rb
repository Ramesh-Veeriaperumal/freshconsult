class Freshfone::Config
	WHITELIST_NUMBERS = YAML::load_file(File.join(Rails.root, 'config/freshfone', 'whitelist.yml'))
end