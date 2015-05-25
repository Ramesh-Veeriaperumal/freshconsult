dynamodb_config = File.join(Rails.root,"config","dynamo_db.yml")

begin  
  $social_dynamoDb = AWS::DynamoDB::ClientV2.new()
rescue => e
  puts "AWS::DynamoDB connection establishment failed."
end

#Configuration for dynamoDB tables
DYNAMO_DB_CONFIG = (YAML::load_file dynamodb_config)[Rails.env]
