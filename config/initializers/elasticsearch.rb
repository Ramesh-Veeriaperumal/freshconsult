unless Rails.env.development? 
	es_urls = YAML::load_file(File.join(RAILS_ROOT, 'config', 'elasticsearch.yml'))[RAILS_ENV][:hosts]
	Tire.configure { url es_urls.first }
end