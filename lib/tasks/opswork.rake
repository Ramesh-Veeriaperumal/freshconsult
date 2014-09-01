namespace :opswork do 
  desc "opsworks scripts"

  def opsworks_config
    YAML::load_file(File.join(Rails.root, 'config', 'opsworks.yml'))[Rails.env].symbolize_keys!
  end

  task :deploy => :environment do
    stack_config = opsworks_config
    config_obj = AWS.config(stack_config[:access_config])
    deploy_config = stack_config[:stack_details].merge(stack_config[:deploy_details])
    AWS::OpsWorks::Client.new(:config => config_obj).create_deployment(deploy_config)
  end
end