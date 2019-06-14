class PodDnsUpdate
  include Sidekiq::Worker 

  DNS_CONFIG = YAML.load_file(File.join(Rails.root, 'config', 'pod_dns_config.yml'))

  sidekiq_options :queue => :pod_route_update, :retry => 0, :failures => :exhausted

  def perform(request_parameters)
    if request_parameters["target_method"]
      remove_from_global_pod(request_parameters)
    else
      map_cname_to_domain(request_parameters)
    end
  end

  private

  def remove_from_global_pod(request_parameters)
    Rails.logger.debug("Received Params: : #{request_parameters.inspect}")
    global_pod_response = Fdadmin::APICalls.connect_main_pod(request_parameters)
  end

  def map_cname_to_domain(domain_config)
  	route53 = AWS::Route53::Client.new(:access_key_id => PodConfig["access_key_id"],
  		:secret_access_key => PodConfig["secret_access_key"],
  		:region => PodConfig["region"])
  	route53.change_resource_record_sets({
	  :hosted_zone_id => DNS_CONFIG["hosted_zone"],
	  :change_batch => {
	    :changes => handle_dns_action(domain_config)
	  }
	  }) 
  end

  def cname_attributes(domain_config)
  	return { 
	  :action => domain_config["action"],
	  :resource_record_set => {
	    :name => domain_config["domain_name"],
	    :type => "CNAME",
	    :ttl => DNS_CONFIG["CNAME"]["ttl"],
	    :resource_records => [{:value => DNS_CONFIG["CNAME"]["value"][domain_config["region"]]}]
		}}
  end

  def handle_dns_action(domain_config)
    if domain_config["action"].eql?('UPDATE')
      return [cname_attributes(domain_config.merge("action" => 'CREATE')),
       cname_attributes(domain_config.merge("action" => 'DELETE',"domain_name" => domain_config["old_domain"]))]
     else 
      return [cname_attributes(domain_config)]
    end
  end
  
end