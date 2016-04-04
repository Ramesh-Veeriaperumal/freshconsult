tokens = YAML::load_file(File.join(Rails.root, 'config', 'autopilot.yml'))
AUTOPILOT_TOKENS = tokens["autopilot"][Rails.env]