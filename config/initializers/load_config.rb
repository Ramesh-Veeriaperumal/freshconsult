AppConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'config.yml'))

NodeConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'node_js.yml'))[RAILS_ENV]

FreshfoneConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'freshfone.yml'))

AddonConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'addons.yml'))
