ES_ENABLED = !Rails.env.development?  
puts "elasticsearch is #{ES_ENABLED ? 'enabled' : 'not enabled'}" 
if ES_ENABLED
	Es_urls = YAML::load_file(File.join(RAILS_ROOT, 'config', 'elasticsearch.yml'))[RAILS_ENV][:hosts]
	Tire.configure { url Es_urls.first }
end