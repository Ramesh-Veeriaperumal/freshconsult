config = YAML::load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)

S3_CONFIG = (config[Rails.env] || config).symbolize_keys

AWS.config(
    :access_key_id => S3_CONFIG[:access_key_id],
    :secret_access_key => S3_CONFIG[:secret_access_key],
    :region => S3_CONFIG[:region],
    :s3_signature_version => :v4)

Aws.config.update({
  region: S3_CONFIG[:region]
})
  
$s3_client = Aws::S3::Client.new(
  region: S3_CONFIG[:region],
  access_key_id: S3_CONFIG[:access_key_id],
  secret_access_key: S3_CONFIG[:secret_access_key],
  signature_version: 'v4'
)

$sqs_euc = AWS::SQS.new(
  :access_key_id => S3_CONFIG[:access_key_id_euc],
  :secret_access_key => S3_CONFIG[:secret_access_key_euc],
  :region => S3_CONFIG[:region_euc],
  :s3_signature_version => :v4)
