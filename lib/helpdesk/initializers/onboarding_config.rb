tokens = YAML::load_file(File.join(Rails.root, 'config', 'onboarding.yml'))
ONBOARDING_CONFIG = tokens["onboarding"]