module EbayConfig

  config = File.join(Rails.root, 'config', 'ecommerce.yml')
  KEYS = (YAML::load_file config)["eBay"]

  Ebayr.app_id = KEYS['app_id']
  Ebayr.dev_id = KEYS['dev_id']
  Ebayr.cert_id = KEYS['cert_id']
  Ebayr.ru_name = KEYS['ru_name']
  Ebayr.sandbox = KEYS['sandbox']
  Ebayr.compatability_level = KEYS['compatability_level']
  AUTHORIZE_URL = KEYS['authorize_url']
end
