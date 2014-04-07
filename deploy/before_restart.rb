if node[:opsworks] 
  if node[:opsworks][:instance][:hostname].include?("-app-") && ::File.exists?("#{release_path}/config/database.yml")
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake cloudfront_assets:upload"
  end
else
  #delayed_job monit has some problem with file permissions.
  #refer http://community.engineyard.com/discussions/problems/1485-delayed_job-worker-not-starting-permission-denied
  run "sudo chmod 755 #{config.release_path}/script/runner"

  # Added a compilation of core css files used under public/src/app
  # All files in public/stylesheets/app will be ignored and cannot be checked in
  on_app_servers do
  	puts "config.current_role:::::::::#{config.current_role}"
  	if config.current_role == "app_master" || config.current_role == "solo"
  		run "RAILS_ENV=#{config.node[:environment][:framework_env]} bundle exec rake cloudfront_assets:upload"
  	else
  		run "RAILS_ENV=#{config.node[:environment][:framework_env]} bundle exec rake cloudfront_assets:compile"
  	end
  end
end