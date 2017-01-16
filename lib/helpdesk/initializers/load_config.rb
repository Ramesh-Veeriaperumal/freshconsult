AppConfig = YAML.load_file(File.join(Rails.root, 'config', 'config.yml')).with_indifferent_access

INTEGRATION_URL = URI.parse(AppConfig['integrations_url'][Rails.env]).host

GLOBAL_INTEGRATION_URL = URI.parse(AppConfig['global_integration_url'][Rails.env]).host

FreshopsSubdomains =  AppConfig['freshops_subdomain'].map { |k,v| v }.flatten

NodeConfig = YAML.load_file(File.join(Rails.root, 'config', 'node_js.yml'))[Rails.env]

FreshfoneConfig = YAML.load_file(File.join(Rails.root, 'config', 'freshfone.yml'))[Rails.env]

MailgunConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailgun.yml'))[Rails.env]

AddonConfig = YAML.load_file(File.join(Rails.root, 'config', 'addons.yml'))

MailboxConfig = YAML.load_file(File.join(Rails.root, 'config', 'mailbox.yml'))[Rails.env]

BraintreeConfig = YAML.load_file(File.join(Rails.root, 'config', 'braintree.yml'))

RateLimitConfig = YAML.load_file(File.join(Rails.root, 'config', 'rate_limit.yml'))[Rails.env]

ChromeExtensionConfig = YAML.load_file(File.join(Rails.root, 'config', 'chrome_extension.yml'))[Rails.env]

MobileConfig = YAML.load_file(File.join(Rails.root, 'config', 'mobile_config.yml'))

AdminApiConfig = YAML.load_file(File.join(Rails.root,'config','fdadmin_api_config.yml'))

PodConfig = YAML.load_file(File.join(Rails.root, 'config', 'pod_info.yml'))

AutoIncrementId = YAML.load_file(File.join(Rails.root,'config','auto_increment_ids.yml'))[Rails.env][PodConfig["CURRENT_POD"]]

HashedData = YAML.load_file(File.join(Rails.root,'config','hashed_data.yml'))[Rails.env]

ThirdPartyAppConfig = YAML::load_file File.join(Rails.root, 'config', 'third_party_app_config.yml')

MlAppConfig = YAML.load_file(File.join(Rails.root,'config','ml_app.yml'))[Rails.env]

FdNodeConfig = YAML.load_file(File.join(Rails.root, 'config', 'fd_node_config.yml'))[Rails.env]

ArchiveNoteConfig = YAML::load_file(File.join(Rails.root, 'config', 'archive_note.yml'))[Rails.env]

IrisNotificationsConfig = YAML::load_file(File.join(Rails.root, 'config', 'iris_notifications.yml'))[Rails.env]
