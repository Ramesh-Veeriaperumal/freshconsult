AppConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'config.yml'))

SplunkConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'splunk.yml'))

NodeConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'node_js.yml'))[RAILS_ENV]