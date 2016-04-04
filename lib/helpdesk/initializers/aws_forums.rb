begin
	$sqs_forum_moderation = AWS::SQS.new.queues.named(SQS[:forums_moderation_queue])

	$dynamo = AWS::DynamoDB::ClientV2.new

rescue => e
	puts "AWS connection establishment failed for Forums"
end

