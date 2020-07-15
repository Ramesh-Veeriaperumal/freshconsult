# AWS SDK V2 Dynamo Client
begin
  $dynamo_v2_client = Aws::DynamoDB::Client.new(DYNAMO_SDK2_CREDS)
rescue
  puts "Dynamo SDK2 establishment failed"
end