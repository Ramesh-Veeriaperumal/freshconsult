# AWS SDK V2 SQS Client
begin
  SQS_V2_CLIENT = Aws::SQS::Client.new(SQS_SDK2_CREDS)
rescue
  puts "SQS SDK2 establishment failed"
end