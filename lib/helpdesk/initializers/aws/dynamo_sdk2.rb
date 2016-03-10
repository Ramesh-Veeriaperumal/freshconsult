# AWS SDK V2 Dynamo Client
begin
  DYNAMO_V2_CLIENT = Aws::DynamoDB::Client.new(DYNAMO_SDK2_CREDS)
rescue
  puts "Dynamo SDK2 establishment failed"
end