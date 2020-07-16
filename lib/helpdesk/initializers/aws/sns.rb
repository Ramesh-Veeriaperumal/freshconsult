sns_config = File.join(Rails.root,"config","sns.yml")

SNS = (YAML::load_file sns_config)[Rails.env]

begin
  #Global SNS client
  $sns_client = AWS::SNS.new.client

rescue => e
  puts "AWS::SNS connection establishment failed."
end
