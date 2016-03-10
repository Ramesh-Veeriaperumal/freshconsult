AWS_SDK2_CREDS    = YAML::load_file(File.join(Rails.root,"config","aws_v2.yml"))
DYNAMO_SDK2_CREDS = AWS_SDK2_CREDS[:dynamo][Rails.env.to_sym]
SQS_SDK2_CREDS    = AWS_SDK2_CREDS[:sqs][Rails.env.to_sym]