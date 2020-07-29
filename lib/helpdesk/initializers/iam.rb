module Iam
  IAM_CONFIG = YAML.load_file(Rails.root.join('config', 'iam.yml'))[Rails.env]
  secrets_mapping = {}
  IAM_CONFIG['client_secrets'].each_key do |service|
    raise StandardError, 'Duplicate client_id\'s found' if secrets_mapping.key?(IAM_CONFIG['client_secrets'][service]['client_id'])

    secrets_mapping[IAM_CONFIG['client_secrets'][service]['client_id']] = IAM_CONFIG['client_secrets'][service]['client_secret']
  end
  IAM_CLIENT_SECRETS = secrets_mapping.freeze
end
