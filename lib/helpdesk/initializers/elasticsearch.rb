ES_ENABLED = !Rails.env.development?  
puts "elasticsearch is #{ES_ENABLED ? 'enabled' : 'not enabled'}" 
if ES_ENABLED
	tire_config = YAML::load_file(File.join(Rails.root, 'config', 'elasticsearch.yml'))[Rails.env]
	Es_aws_urls = tire_config[:aws_hosts]
	Tire.configure { url Es_aws_urls.first }

  COUNT_HOST = tire_config[:count_host].first
end