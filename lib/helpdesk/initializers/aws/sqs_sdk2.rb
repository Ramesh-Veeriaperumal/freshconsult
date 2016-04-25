# AWS SDK V2 SQS Client
begin
  $sqs_v2_client = Aws::SQS::Client.new(SQS_SDK2_CREDS)
rescue
  puts "SQS SDK2 establishment failed"
end