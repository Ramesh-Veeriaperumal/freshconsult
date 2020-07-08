AWS_SDK2_CREDS    = YAML::load_file(File.join(Rails.root,"config","aws_v2.yml"))[Rails.env.to_sym]
DYNAMO_SDK2_CREDS = AWS_SDK2_CREDS[:dynamo]
SQS_SDK2_CREDS    = AWS_SDK2_CREDS[:sqs]

# PRE-RAILS: Moved pod_info as Route53 used it in v1
PodConfig = YAML.load_file(Rails.root.join('config', 'pod_info.yml').to_path)

$route_53 = Aws::Route53::Client.new(region: PodConfig['region'], access_key_id: PodConfig['access_key_id'], secret_access_key: PodConfig['secret_access_key'])
