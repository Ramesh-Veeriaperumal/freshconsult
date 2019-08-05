ES_ENABLED = true #!Rails.env.development?
puts "elasticsearch is #{ES_ENABLED ? 'enabled' : 'not enabled'}" 
if ES_ENABLED
	tire_config = YAML::load_file(File.join(Rails.root, 'config', 'elasticsearch.yml'))[Rails.env]
	Es_aws_urls = tire_config[:aws_hosts]
	Tire.configure { url Es_aws_urls.first }

  COUNT_V2_HOST = tire_config[:count_v2_host].first
end
