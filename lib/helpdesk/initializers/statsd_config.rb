statsd_config = YAML.load_file(File.join(Rails.root, 'config', 'statsd.yml'))[Rails.env]
# $statsd = Statsd::Statsd.new(statsd_config["host"], statsd_config["port"])