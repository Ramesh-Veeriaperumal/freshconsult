SKIP_MIDDLEWARES = YAML::load_file(File.join(Rails.root,'config','skip_all_middlewares.yml'))[Rails.env]
