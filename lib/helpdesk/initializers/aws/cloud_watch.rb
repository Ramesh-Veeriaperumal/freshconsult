begin
  
  $cloud_watch = Aws::CloudWatch::Client.new(
    credentials: Aws::InstanceProfileCredentials.new
  )

rescue => e
  puts "AWS::CloudWatch connection establishment failed."
end
