config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/s3.yml")).result)
sqs_config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/sqs.yml")).result)
sns_config = File.join(Rails.root,"config","sns.yml")
dynamodb_config = File.join(Rails.root,"config","dynamo_db.yml")

S3_CONFIG = (config[Rails.env] || config).symbolize_keys
SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys
SNS = (YAML::load_file sns_config)[Rails.env]

AWS.config(
		:access_key_id => S3_CONFIG[:access_key_id],
		:secret_access_key => S3_CONFIG[:secret_access_key])

#Global SNS and SQS clients
$sns_client = AWS::SNS.new.client
$sqs_client = AWS::SQS.new.client

#for sqs queue facebook
$sqs_facebook = AwsWrapper::Sqs.new(SQS[:facebook_realtime_queue])

# Initializing global variable polling the tweets from sqs
$sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])

# ticket auto refresh sqs queue
$sqs_autorefresh = AwsWrapper::Sqs.new(SQS[:auto_refresh_realtime_queue])

$social_dynamoDb = AWS::DynamoDB::ClientV2.new()

#Configuration for dynamoDB tables
DYNAMO_DB_CONFIG = (YAML::load_file dynamodb_config)[Rails.env]