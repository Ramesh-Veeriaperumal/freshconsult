class Freshfone::Cost
	NUMBERS = YAML::load_file(File.join(Rails.root, 'config/freshfone', 'number-rates.yml'))
end