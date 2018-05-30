module ApigeeConfig

  config = YAML::load_file(File.join(Rails.root, 'config', 'apigee.yml'))[Rails.env]
  URL = config['url'].freeze
  ENDPOINT = config['path'].freeze
  API_KEY = config['api_key'].freeze
  BASE_URI = "#{URL}#{ENDPOINT}".freeze
  CLEAR_CACHE_PATH = config['clear_cache_path'].freeze
  CLEAR_CACHE_URI = "#{URL}#{CLEAR_CACHE_PATH}".freeze
  UPDATE_KVM_PATH = config['update_kvm_path'].freeze
  UPDATE_KVM_URI = "#{URL}#{UPDATE_KVM_PATH}".freeze
  S3_BUCKET_NAME = config['s3_bucket_name'].freeze
  S3_FILE_NAME = config['s3_file_name'].freeze
  ALLOWED_ACTIONS = %W(create update delete).freeze
  ALLOWED_PLANS = %W(sprout sprout_min blossom blossom_min garden garden_min estate estate_min forest forest_min addon1 addon2 addon3 addon4).freeze
end