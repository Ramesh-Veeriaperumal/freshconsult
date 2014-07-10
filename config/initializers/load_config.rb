AppConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'config.yml'))

NodeConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'node_js.yml'))[RAILS_ENV]

FreshfoneConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'freshfone.yml'))[RAILS_ENV]

MailgunConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'mailgun.yml'))[RAILS_ENV]

AddonConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'addons.yml'))

MailboxConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'mailbox.yml'))[RAILS_ENV]

BraintreeConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'braintree.yml'))

RateLimitConfig = YAML.load_file(File.join(RAILS_ROOT, 'config', 'rate_limit.yml'))[RAILS_ENV]
