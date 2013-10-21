config = YAML::load(ERB.new(File.read("#{RAILS_ROOT}/config/s3.yml")).result)
sqs_config = File.join(Rails.root,"config","sqs.yml")

S3_CONFIG = (config[Rails.env] || config).symbolize_keys
SQS = (YAML::load_file sqs_config)[Rails.env]

AWS.config(	
		:access_key_id => S3_CONFIG[:access_key_id],
		:secret_access_key => S3_CONFIG[:secret_access_key])


# Initializing global variable polling the tweets from sqs
$sqs_twitter = AWS::SQS.new.queues.named(SQS["twitter_realtime_queue"])
