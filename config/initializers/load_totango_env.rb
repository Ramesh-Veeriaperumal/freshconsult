config = File.join(Rails.root, 'config', 'totango.yml')
tokens = (YAML::load_file config)[Rails.env]
TotangoServiceId = tokens['service_id']