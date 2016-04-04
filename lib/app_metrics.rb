module AppMetrics
	FRESHFONE_METRICS = YAML.load_file(File.join(Rails.root, 'config', 'app_metrics.yml'))["kissmetrics"]["freshfone"][Rails.env]
	FRESHFONE_METRIC_EVENTS = YAML.load_file(File.join(Rails.root, 'config', 'metric_events.yml'))
end
