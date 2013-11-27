config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/s3.yml")).result)
sqs_config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/sqs.yml")).result)

S3_CONFIG = (config[Rails.env] || config).symbolize_keys
SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys

AWS.config(	
		:access_key_id => S3_CONFIG[:access_key_id],
		:secret_access_key => S3_CONFIG[:secret_access_key])

#for sqs queue facebook
$sqs_facebook = AwsWrapper::Sqs.new(SQS[:facebook_realtime_queue])

# Initializing global variable polling the tweets from sqs
$sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])
