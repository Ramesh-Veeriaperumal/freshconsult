if node[:opsworks]
	master_node = node[:opsworks][:layers][:application][:instances].keys.sort.first  if node[:opsworks][:layers] && node[:opsworks][:layers][:application] && node[:opsworks][:layers][:application][:instances]
  master_node = node[:rails3][:asset_pipeline_host] if node[:rails3] && node[:rails3][:asset_pipeline_host]
  if master_node && (node[:opsworks][:instance][:hostname] == master_node) && ::File.exists?("#{release_path}/config/database.yml")
    if node[:custom_db_migrate]
    	run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake db:migrate"
    end
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:sync"
  elsif node[:opsworks][:instance][:hostname].include?("-app-") && ::File.exists?("#{release_path}/config/database.yml")
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
  end
end
