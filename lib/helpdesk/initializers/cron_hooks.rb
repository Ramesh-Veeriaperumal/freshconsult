file_path = Rails.root.join('config', 'cron_hooks.yml')
config = YAML.safe_load(ERB.new(File.read(file_path)).result)[Rails.env]

CRON_HOOK_DOMAIN = config['webhook_domain']
CRON_HOOK_SUBDOMAIN = config['webhook_subdomain']
CRON_HOOK_AUTH_KEY = config['auth_key']
CRON_HOOK_ACCOUNT_AUTH_KEY = config['account_based_auth_key']
