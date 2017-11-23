HEALTH_CHECK_PATH = YAML::load_file(File.join(Rails.root,'config','health_check.yml'))[Rails.env]
