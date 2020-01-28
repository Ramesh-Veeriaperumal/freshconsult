module Iam
  IAM_CONFIG = YAML.load_file(Rails.root.join('config', 'iam.yml'))[Rails.env]
end
