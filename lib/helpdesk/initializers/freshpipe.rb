module Freshpipe
  config = File.join(Rails.root, 'config', 'freshpipe_configs.yml')
  hash = (YAML::load_file config)
  SECRET_KEYS = hash["secret_keys"]
end