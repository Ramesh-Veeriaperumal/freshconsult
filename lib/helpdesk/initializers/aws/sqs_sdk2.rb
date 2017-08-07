# AWS SDK V2 SQS Client
begin
  $sqs_v2_client = if Rails.env.test?
                     Aws::SQS::Client.new(stub_responses: true)
                   else
                     Aws::SQS::Client.new(SQS_SDK2_CREDS)
                   end
rescue
  Rails.logger.debug 'SQS SDK2 establishment failed'
end
