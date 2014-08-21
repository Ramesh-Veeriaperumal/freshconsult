if node[:opsworks]
  require 'aws-sdk'
  # establishing connection with aws to run custom restart of nginx
  awscreds = {
    :access_key_id    => node[:opsworks_access_keys][:access_key_id],
    :secret_access_key => node[:opsworks_access_keys][:secret_access_key],
    :region           => node[:opsworks_access_keys][:region]
  }

  AWS.config(awscreds)

  # intializing the opsworks client object
  opsworks = AWS::OpsWorks::Client.new
  # finding the master node
  master_node = ""
  if node[:opsworks][:instance][:layers] && node[:opsworks][:layers][:application] && !node[:opsworks][:layers][:application][:instances].blank?
    master_node = node[:opsworks][:layers][:application][:instances].keys.sort.first
  end
  if master_node
    # master_node id for triggering the deployment
    if !master_node.blank?
      master_node_id = node[:opsworks][:layers][:application][:instances][master_node][:id]
      # describing the current deployment for finding all the instances on which deployment is triggered
      instance_ids = []
    end

    # checking if this is deployment or new instance
    if node[:opsworks][:deployment]
      deployment = opsworks.describe_deployments(:deployment_ids => node[:opsworks][:deployment])
      # getting the deployment details
      deployment_details = deployment[:deployments].first
      # getting the stack_id
      stack_id = deployment_details[:stack_id]
      # getting all the instances where nginx restart should be triggered
      instance_ids = deployment_details[:instance_ids]
    end
    # check if instance_id include master_node because the deployment would be triggered from
    # master node else restart nginx that means a partial deployment
    if master_node_id && instance_ids.include?(master_node_id)
      # trigger deployment incase of masternode else don't do anything
      if node[:opsworks][:instance][:hostname] == master_node
        # custom_json = "{\"custom_deployment_id\":\"#{node[:opsworks][:deployment].first}\",\"custom_stack_id\":\"#{stack_id}\"}"
        opsworks.create_deployment({
                                     :stack_id =>  stack_id,
                                     :instance_ids => instance_ids,
                                     :command => {
                                       :name =>  "execute_recipes",
                                       :args => {
                                         "recipes" => ["deploy::helpkit_restart_services"]
                                       }
                                     },
                                     :comment => "service restart from master"

        })
        newrelic_key = (node["opsworks"]["environment"] == "production") ? "53e0eade912ffb2c559d6f3c045fe363609df3ee" : "7a4f2f3abfd0f8044580034278816352324a9fb7"
        long_user_string = node["deploy"][node["opsworks"]["applications"][0]["slug_name"]]["deploying_user"]
        #something like: "arn:aws:iam::(long-number):user/username"
        username = long_user_string.split('/').last
        Chef::Log.debug "curl -H \"x-license-key:#{newrelic_key}\" -d \"deployment[app_name]=#{node['opsworks']['stack']['name']} / helpkit (#{node['opsworks']['environment']})\" -d \"deployment[user]=#{username}\" https://rpm.newrelic.com/deployments.xml"
        begin
          run "curl -H \"x-license-key:#{newrelic_key}\" -d \"deployment[app_name]=#{node['opsworks']['stack']['name']} / helpkit (#{node['opsworks']['environment']})\" -d \"deployment[user]=#{username}\" https://rpm.newrelic.com/deployments.xml"
        rescue  Exception => e  
          Chef::Log.debug "The following error occurred: #{e.message}"
        end
      end
    else
      # restart nginx for custom deployment without master only for old instances
      if stack_id
        instance_ids = [node[:opsworks][:instance][:id]]
        opsworks.create_deployment({
                                     :stack_id =>  stack_id,
                                     :instance_ids => instance_ids,
                                     :command => {
                                       :name =>  "execute_recipes",
                                       :args => {
                                         "recipes" => ["deploy::helpkit_restart_services"]
                                       }
                                     },
                                     :comment => "service restart by node"
        })
      end
    end
  end
  Chef::Log.debug("************ after after restart ************* ")
else
  def all_instances_of(engine)
    utility_instances = []
    config.node['utility_instances'].each do |utility|
      if utility['name'].include?(engine)
        utility_instances << utility['name']
      end
    end
    utility_instances << 'freshdesk_utility' if utility_instances
    utility_instances
  end

  #To restart delayed_job workers..
  # on_utilities(all_instances_of("freshdesk_utility")) do
  #   run "sudo monit -g dj_helpkit restart all"
  # end

  on_utilities(all_instances_of('reports_app_')) do
    run "sudo /etc/init.d/nginx restart" 
  end

  # on_utilities(all_instances_of('resque')) do
  # 	run "sudo monit restart all -g helpkit_resque" 
  # end

  # on_utilities(all_instances_of('twitter_utility')) do
  #   run "sudo monit restart all -g helpkit_twitter_realtime"
  # end

  # on_utilities(all_instances_of('facebook_utility')) do
  #   run "sudo monit restart all -g helpkit_facebook_realtime"
  # end


  if config.current_role == "app_master"
    newrelic_key = (config.framework_env == "production") ? "53e0eade912ffb2c559d6f3c045fe363609df3ee" : "7a4f2f3abfd0f8044580034278816352324a9fb7"
    begin
      run "curl -H \"x-license-key:#{newrelic_key}\" -d \"deployment[app_name]=#{config.environment_name} / helpkit (#{config.framework_env})\" -d \"deployment[revision]=#{config.revision}\" -d \"deployment[user]=#{config.deployed_by}\" https://rpm.newrelic.com/deployments.xml"
    rescue  Exception => e  
      puts "The following error occurred: #{e.message}"
    end
    # Deploying the opsworks...
    run "RAILS_ENV=#{config.node[:environment][:framework_env]} bundle exec rake opswork:deploy"
  end

  if config.framework_env == "staging"
    on_utilities(all_instances_of('workers')) do
      run "sudo monit -g dj_helpkit restart all"
      run "sudo monit restart all -g helpkit_resque" 
      run "sudo monit restart all -g helpkit_twitter_realtime"
      run "sudo monit restart all -g helpkit_facebook_realtime"
    end
  end

end