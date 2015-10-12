config = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)

S3_CONFIG = (config[Rails.env] || config).symbolize_keys

AWS.config(
    :access_key_id => S3_CONFIG[:access_key_id],
    :secret_access_key => S3_CONFIG[:secret_access_key],
    :region => S3_CONFIG[:region])

Aws.config.update({
  region: S3_CONFIG[:region]
})
  
$s3_client = Aws::S3::Client.new(
  region: S3_CONFIG[:region],
  access_key_id: S3_CONFIG[:access_key_id],
  secret_access_key: S3_CONFIG[:secret_access_key]
)

# using dummy credentials. To be changed before QA starts
$dynamo_client = (Rails.env.development? || Rails.env.test?) ? 
                  Aws::DynamoDB::Client.new(endpoint: 'http://localhost:8000', access_key_id: 'dummy', secret_access_key: 'dummy') :
                  Aws::DynamoDB::Client.new(region: S3_CONFIG[:region], access_key_id: S3_CONFIG[:access_key_id], secret_access_key: S3_CONFIG[:secret_access_key])