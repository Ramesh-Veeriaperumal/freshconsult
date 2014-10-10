AppConfig = YAML.load_file(File.join(Rails.root, 'config', 'config.yml'))

NodeConfig = YAML.load_file(File.join(Rails.root, 'config', 'node_js.yml'))[Rails.env]

FreshfoneConfig = YAML.load_file(File.join(Rails.root, 'config', 'freshfone.yml'))[Rails.env]

MailgunConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailgun.yml'))[Rails.env]

AddonConfig = YAML.load_file(File.join(Rails.root, 'config', 'addons.yml'))

MailboxConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailbox.yml'))[Rails.env]

BraintreeConfig = YAML.load_file(File.join(Rails.root, 'config', 'braintree.yml'))

RateLimitConfig = YAML.load_file(File.join(Rails.root, 'config', 'rate_limit.yml'))[Rails.env]

ChromeExtensionConfig = YAML.load_file(File.join(Rails.root, 'config', 'chrome_extension.yml'))[Rails.env]

MobileConfig = YAML.load_file(File.join(Rails.root, 'config', 'mobile_config.yml'))
