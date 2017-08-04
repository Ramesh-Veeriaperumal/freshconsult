if node[:opsworks]
  require 'aws-sdk'
  # establishing connection with aws to run custom restart of nginx
  awscreds = {
     :access_key_id    => node[:opsworks_access_keys][:access_key_id],
     :secret_access_key => node[:opsworks_access_keys][:secret_access_key],
     :region           => node[:opsworks_access_keys][:opsworks_region]
  }

  #TODO-RAILS3 once migrations is done we can remove setting from stack and bellow code.
  # unless node[:rails3][:use_iam_profile]
  #   awscreds.merge!({
  #     :access_key_id    => node[:opsworks_access_keys][:access_key_id],
  #     :secret_access_key => node[:opsworks_access_keys][:secret_access_key]
  #   })
  # end

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
      deployment = opsworks.describe_deployments(:deployment_ids => [node[:opsworks][:deployment]])
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
        
        if node[:new_asset_compilation]
          target_instance_ids = [node[:opsworks][:instance][:id]]
          recipe_list = ["asset_compilation::setup", "deploy::rolling_restart"]
        else
          target_instance_ids = instance_ids
          recipe_list = ["deploy::helpkit_restart_services"]
        end

        opsworks.create_deployment({
                                     :stack_id =>  stack_id,
                                     :instance_ids => target_instance_ids,
                                     :command => {
                                       :name =>  "execute_recipes",
                                       :args => {
                                         "recipes" => recipe_list
                                       }
                                     },
                                     :comment => "service restart from master",
                                     :custom_json => { :deployed_instance_ids => instance_ids }.to_json
        })

        newrelic_key = (node["opsworks"]["environment"] == "production") ? "53e0eade912ffb2c559d6f3c045fe363609df3ee" : "7de9fc43e005937140bf898eed"
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

        recipe_list = ["deploy::helpkit_restart_services"]

        if node[:new_asset_compilation] && (node[:opsworks][:instance][:hostname].include?("-app-"))
          Chef::Log.info "Adding asset flag file on deployment without master"
          ::File.open("#{release_path}/#{node[:rails_assets][:flag_file]}", "w") {}

          recipe_list = ["asset_compilation::generate"]
        end

        opsworks.create_deployment({
                                     :stack_id =>  stack_id,
                                     :instance_ids => instance_ids,
                                     :command => {
                                       :name =>  "execute_recipes",
                                       :args => {
                                         "recipes" => recipe_list
                                       }
                                     },
                                     :comment => "service restart by node"
        })
      end
    end
  end
  Chef::Log.debug("************ after after restart ************* ")
end
