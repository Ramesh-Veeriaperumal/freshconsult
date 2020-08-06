sns_config = File.join(Rails.root,"config","sns.yml")

SNS = (YAML::load_file sns_config)[Rails.env]

begin
  # PRE-RAILS: V1 AWS Client configured with S3_CONFIG, present in aws_s3.rb
  $sns_client = Aws::SNS::Client.new(access_key_id: S3_CONFIG[:access_key_id], secret_access_key: S3_CONFIG[:secret_access_key], region: S3_CONFIG[:region])

rescue => e
  puts "AWS::SNS connection establishment failed."
end
