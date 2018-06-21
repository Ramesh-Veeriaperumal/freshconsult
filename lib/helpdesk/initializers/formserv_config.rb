config = Rails.root.join('config', 'formserv.yml').to_path
FORMSERV_CONFIG = (YAML.load_file config)[Rails.env]
