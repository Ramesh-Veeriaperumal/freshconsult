module AppMetrics
	MIXPANEL_ID = YAML.load_file(File.join(RAILS_ROOT, 'config', 'app_metrics.yml'))["mixpanel"]
end
