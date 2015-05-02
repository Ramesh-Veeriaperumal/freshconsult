sqs_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/sqs.yml")).result)
sns_config = File.join(Rails.root,"config","sns.yml")
dynamodb_config = File.join(Rails.root,"config","dynamo_db.yml")

SQS = (sqs_config[Rails.env] || sqs_config).symbolize_keys
SNS = (YAML::load_file sns_config)[Rails.env]

begin
	#Global SNS and SQS clients
	$sns_client = AWS::SNS.new.client
	$sqs_client = AWS::SQS.new.client

	#for sqs queue facebook
	$sqs_facebook = AwsWrapper::Sqs.new(SQS[:facebook_realtime_queue])

	# Initializing global variable polling the tweets from sqs
	$sqs_twitter = AWS::SQS.new.queues.named(SQS[:twitter_realtime_queue])

	# ticket auto refresh sqs queue
	$sqs_autorefresh = AwsWrapper::Sqs.new(SQS[:auto_refresh_realtime_queue])

	# custom mailbox sqs queue
	$sqs_mailbox = AWS::SQS.new.queues.named(SQS[:custom_mailbox_realtime_queue])

	$social_dynamoDb = AWS::DynamoDB::ClientV2.new()

rescue => e
	puts "AWS::SQS connection establishment failed."
end

#Configuration for dynamoDB tables
DYNAMO_DB_CONFIG = (YAML::load_file dynamodb_config)[Rails.env]
