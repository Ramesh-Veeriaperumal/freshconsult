module AppMetrics
	MIXPANEL_ID = YAML.load_file(File.join(Rails.root, 'config', 'app_metrics.yml'))["mixpanel"]
end
