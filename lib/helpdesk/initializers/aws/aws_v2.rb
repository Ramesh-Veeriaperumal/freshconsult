AWS_SDK2_CREDS    = YAML::load_file(File.join(Rails.root,"config","aws_v2.yml"))[Rails.env.to_sym]
DYNAMO_SDK2_CREDS = AWS_SDK2_CREDS[:dynamo]
SQS_SDK2_CREDS    = AWS_SDK2_CREDS[:sqs]