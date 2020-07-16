# Removing Asset compilation from here.
# Falcon will not be using asset compilation like helpkit does.
require 'aws-sdk'
require 'logger'
AWS.config(logger: Logger.new($stdout), log_level: :debug, s3_signature_version: :v4)

if node[:new_asset_compilation]
  # Asset compilation / download only on instance setup.
  if node[:opsworks][:instance][:hostname].include?('-app-') && !::File.exist?("#{release_path}/config/database.yml")
    Chef::Log.info 'Adding asset flag file on instance setup'
    ::File.open("#{release_path}/#{node[:rails_assets][:flag_file]}", 'w') {}
  end

  master_node = node[:opsworks][:layers][:application][:instances].keys.sort.first if node[:opsworks][:layers] && node[:opsworks][:layers][:application] && node[:opsworks][:layers][:application][:instances]
  run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake db:migrate" if (master_node == node[:opsworks][:instance][:hostname]) && node[:custom_db_migrate]
else
  # establishing connection with aws to run custom restart of nginx
  awscreds = {
    access_key_id: node[:opsworks_access_keys][:access_key_id],
    secret_access_key: node[:opsworks_access_keys][:secret_access_key],
    region: node[:opsworks_access_keys][:region]
  }
  # TODO-RAILS3 once migrations is done we can remove setting from stack and bellow code.
  # awscreds.merge!({:access_key_id    => node[:opsworks_access_keys][:access_key_id],
  #                 :secret_access_key => node[:opsworks_access_keys][:secret_access_key]
  #                  }) unless node[:rails3][:use_iam_profile]

  if ::File.exists?("#{node[:rel_path]}/config/database.yml")
    config = YAML::load_file(::File.join(node[:rel_path], 'config', 'asset_sync.yml'))
    bucket_name = config[node[:opsworks][:environment]]['fog_directory']
  end
  # for git version and bucket existence condition
  Dir.chdir node[:newdir].to_s
  git_version_command = 'git log --pretty=format:%H --max-count=1 --branches=HEAD -- ./public/'
  file_name = node.override[:git_version] = `#{git_version_command}` + '.zip'
  node.override[:path] = node[:path].to_s + file_name.to_s
  Chef::Log.info "value of git version is #{node[:git_version]} and test value is #{node[:bucket_exist]} and bucket name is #{bucket_name}"
  asset_pipeline_host = node[:falcon][:asset_pipeline_host] if node[:falcon] && node[:falcon][:asset_pipeline_host]
  if node[:opsworks] && ::File.exists?("#{node[:rel_path]}/config/database.yml")
    if node[:opsworks][:instance][:hostname].include?('-app-')
      aws_config = AWS::S3.new(awscreds).buckets[bucket_name.to_s].objects["compiledfiles/#{file_name}"]
      node.override[:bucket_exist] = aws_config.exists?
    end
    # Lint/UselessAssignment: Useless assignment to variable - master_node.
    # master_node = node[:opsworks][:layers][:application][:instances].keys.sort.first  if node[:opsworks][:layers] && node[:opsworks][:layers][:application] && node[:opsworks][:layers][:application][:instances]
    asset_pipeline_host = node[:falcon][:asset_pipeline_host] if node[:falcon] && node[:falcon][:asset_pipeline_host]
    # Lint/UselessAssignment: Useless assignment to variable - current_host
    # current_host = node[:opsworks][:instance][:hostname]
    if asset_pipeline_host && (node[:opsworks][:instance][:hostname] == asset_pipeline_host) && !aws_config.exists?
      Chef::Log.info 'inside master'
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake db:migrate" if node[:custom_db_migrate]
      Chef::Log.info 'condition for compilation'
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
      run "cd #{release_path} && I18NEMA_ENABLE=false RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
      run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:sync"
      Chef::Log.info "path is #{node[:path]}"
    elsif node[:opsworks][:instance][:hostname].include?('-app-') && ::File.exist?("#{node[:rel_path]}/config/database.yml")
      Chef::Log.info 'iniside salve'
      if !node[:bucket_exist]
        Chef::Log.info 'key not present so compiling by itself'
        run "cd #{release_path} && RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:clean_expired"
        run "cd #{release_path} && I18NEMA_ENABLE=false RAILS_ENV=#{node[:opsworks][:environment]} bundle exec rake assets:precompile:primary"
      else
        Chef::Log.info 'compilation file is already present so downloading it'
        Chef::Log.info "cs3 reference is #{aws_config} "

        Dir.chdir '/data/helpkit/assets'
        ::File.open(file_name.to_s, 'w') do |f|
          f.write(aws_config.read)
          f.close
        end
        bash 'unzip the files' do
          cwd '/'
          user 'root'
          code %(unzip -o #{node[:path]} -d #{node[:rel_path]}/public/)
        end
      end
    end
  end
  if asset_pipeline_host && (node[:opsworks][:instance][:hostname] == asset_pipeline_host) && ::File.exists?("#{node[:rel_path]}/config/database.yml")
    execute 'zip the file' do
      command "cd #{node[:rel_path]}/public/ ; zip -FSr #{node[:path]} assets/*"
    end
    ruby_block 'upload new file' do
      block do
        aws_config.write(file: node[:path])
      end
      action :run
    end
  end
end
