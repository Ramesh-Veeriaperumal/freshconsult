ES_ENABLED = !Rails.env.development?  
puts "elasticsearch is #{ES_ENABLED ? 'enabled' : 'not enabled'}" 
if ES_ENABLED
	tire_config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'elasticsearch.yml'))[RAILS_ENV]
	Es_urls = tire_config[:hosts]
	Es_aws_urls = tire_config[:aws_hosts]
	Tire.configure { url Es_urls.first }
end