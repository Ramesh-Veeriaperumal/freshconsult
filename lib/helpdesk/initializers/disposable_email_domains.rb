require 'freemail'

DISPOSABLE_EMAIL_DOMAINS = YAML::load_file(File.join(Rails.root, 'config', 'disposable_email_domains.yml'))

Freemail.add_disposable_domains(DISPOSABLE_EMAIL_DOMAINS)