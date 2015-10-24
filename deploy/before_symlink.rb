require 'aws-sdk'
require 'logger'
AWS.config(:logger => Logger.new($stdout),:log_level => :debug)

# establishing connection with aws to run custom restart of nginx
awscreds = {
     :access_key_id    => node[:opsworks_access_keys][:access_key_id],
     :secret_access_key => node[:opsworks_access_keys][:secret_access_key],
     :region           => node[:opsworks_access_keys][:region]
}
#TODO-RAILS3 once migrations is done we can remove setting from stack and bellow code.
# awscreds.merge!({:access_key_id    => node[:opsworks_access_keys][:access_key_id],
#                 :secret_access_key => node[:opsworks_access_keys][:secret_access_key]
#                  }) unless node[:rails3][:use_iam_profile]

config = YAML::load_file(::File.join(node[:rel_path], 'config', 'asset_sync.yml'))
bucket_name = config[node[:opsworks][:environment]]["fog_directory"]

#for git version and bucket existence condition
Dir.chdir "#{node[:newdir]}"
git_version_command = "git log --pretty=format:%H --max-count=1 --branches=HEAD -- ./public/"
file_name = node.override[:git_version] = `#{git_version_command}` + ".zip"
node.override[:path] = "#{node[:path]}" + "#{file_name}"
Chef::Log.info "value of git version is #{node[:git_version]} and test value is #{node[:bucket_exist]} and bucket name is #{bucket_name}"

if node[:opsworks]
  if node[:opsworks][:instance][:hostname].include?("-app-")
    aws_config = AWS::S3.new(awscreds).buckets["#{bucket_name}"].objects["compiledfiles/#{file_name}"]
    node.override[:bucket_exist] =  aws_config.exists?
  end
  master_node = node[:opsworks][:layers][:application][:instances].keys.sort.first  if node[:opsworks][:layers] && node[:opsworks][:layers][:application] && node[:opsworks][:layers][:application][:instances]
  asset_pipeline_host = node[:rails3][:asset_pipeline_host] if node[:rails3] && node[:rails3][:asset_pipeline_host]
  current_host = node[:opsworks][:instance][:hostname] 
  if master_node && (node[:opsworks][:instance][:hostname] == master_node) && ::File.exists?("#{node[:rel_path]}/config/database.yml")
    Chef::Log.info "inside master"
    if node[:custom_db_migrate]
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake db:migrate"
    end
    Chef::Log.info "condition for compilation"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
    run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:sync"
    Chef::Log.info "path is #{node[:path]}"
   
  elsif node[:opsworks][:instance][:hostname].include?("-app-") && ::File.exists?("#{node[:rel_path]}/config/database.yml")
   Chef::Log.info "iniside salve" 
    unless (node[:bucket_exist]) 
      Chef::Log.info "key not present so compiling by itself"
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
    else
      Chef::Log.info "compilation file is already present so downloading it"
      Chef::Log.info "cs3 reference is #{aws_config} "

      Dir.chdir "/data/helpkit/assets"
        ::File.open("#{file_name}", "w") do |f|
          f.write(aws_config.read)
          f.close
        end
      bash "unzip the files" do
        cwd '/'
        user 'root'
        code %(unzip -o #{node[:path]} -d #{node[:rel_path]}/public/)
      end
    end
  end
end
if master_node && (node[:opsworks][:instance][:hostname] == master_node) 
execute "zip the file" do 
      command "cd #{node[:rel_path]}/public/ ; zip -FSr #{node[:path]} assets/*"  
    end
    ruby_block 'upload new file' do
     block do
      aws_config.write(:file => node[:path])
      end
     action :run
    end
end