LAMBDA_ENABLED = !Rails.env.development?  
puts "Lambda is #{LAMBDA_ENABLED ? 'enabled' : 'not enabled'}" 

if LAMBDA_ENABLED
  lambda_config = YAML::load(ERB.new(File.read("#{Rails.root}/config/lambda.yml")).result)[Rails.env]

  begin
    #Global Lambda client
    $lambda_client = Aws::Lambda::Client.new(
      region: lambda_config["region"],
      access_key_id: lambda_config["access_key_id"],
      secret_access_key: lambda_config["secret_access_key"]
    )
    $lambda_interchange = lambda_config["resources"].inject({}) do |hash, model|
      hash[model] = lambda_config["#{model}_interchange"]
      hash
    end    
  rescue => e
    puts "AWS::LAMBDA connection establishment failed."
  end
end
