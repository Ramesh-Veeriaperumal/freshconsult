config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/s3.yml")).result)
S3_CONFIG = (config[Rails.env] || config).symbolize_keys

AWS.config(	
		:access_key_id => S3_CONFIG[:access_key_id],
		:secret_access_key => S3_CONFIG[:secret_access_key])