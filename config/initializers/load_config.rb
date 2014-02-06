AppConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'config.yml'))

SplunkConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'splunk.yml'))

NodeConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'node_js.yml'))[RAILS_ENV]

FreshfoneConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'freshfone.yml'))

MailboxConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'mailbox.yml'))[RAILS_ENV]