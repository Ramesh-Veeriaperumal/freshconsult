# AWS SDK V2 Dynamo Client
begin
  $dynamo_v2_client = Aws::DynamoDB::Client.new(DYNAMO_SDK2_CREDS)
rescue
  puts "Dynamo SDK2 establishment failed"
end

# Configuration for dynamoDB tables - used in social
DYNAMO_DB_CONFIG = YAML.load_file(Rails.root.join('config', 'dynamo_db.yml').to_path)[Rails.env]
