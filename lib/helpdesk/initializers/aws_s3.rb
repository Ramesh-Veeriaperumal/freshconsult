config = YAML.load(ERB.new(File.read("#{Rails.root}/config/s3.yml")).result)

S3_CONFIG = (config[Rails.env] || config).symbolize_keys

if Rails.env.test?
  # https://aws.amazon.com/blogs/developer/client-response-stubs/
  # http://docs.aws.amazon.com/sdk-for-ruby/v2/developer-guide/stubbing.html
  # http://docs.aws.amazon.com/sdkforruby/api/Aws/ClientStubs.html
  AWS.stub!
  Aws.config[:stub_responses] = true
end

################################ AWS SDK v1 config ################################

dev_params = (Rails.env.development? || Rails.env.test?) ? {
  sqs_endpoint: 'localhost',
  sqs_port: 4576,
  s3_force_path_style: true,
  ssl_verify_peer: false
} : {}

AWS.config({
  access_key_id: S3_CONFIG[:access_key_id],
  secret_access_key: S3_CONFIG[:secret_access_key],
  region: S3_CONFIG[:region],
  s3_signature_version: :v4
}.merge(dev_params))

################################ AWS SDK v2 config ################################

s3_dev_params = (Rails.env.development? || Rails.env.test?) ? {
  endpoint: 'https://localhost:4572',  
  force_path_style: true,
  ssl_verify_peer: false
} : {}

Aws.config.update(region: S3_CONFIG[:region])

$s3_client = Aws::S3::Client.new({
  region: S3_CONFIG[:region],
  access_key_id: S3_CONFIG[:access_key_id],
  secret_access_key: S3_CONFIG[:secret_access_key],
  signature_version: 'v4'
}.merge(s3_dev_params))

$sqs_euc = AWS::SQS.new(
  access_key_id: S3_CONFIG[:access_key_id_euc],
  secret_access_key: S3_CONFIG[:secret_access_key_euc],
  region: S3_CONFIG[:region_euc],
  s3_signature_version: :v4
)
