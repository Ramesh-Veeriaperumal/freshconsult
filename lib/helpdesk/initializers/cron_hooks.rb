file_path = Rails.root.join('config', 'cron_hooks.yml')
config = Psych.safe_load(ERB.new(File.read(file_path)).result, [], [], true)[Rails.env]

CRON_HOOK_DOMAIN = config['webhook_domain']
CRON_HOOK_SUBDOMAIN = config['webhook_subdomain']
CRON_HOOK_AUTH_KEY = config['auth_key']
