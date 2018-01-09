config = YAML::load_file(File.join(Rails.root, 'config', 'heap_analytics.yml'))[Rails.env]
HEAP_PROJECT_ID = config['app_id']