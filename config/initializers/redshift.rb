config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redshift.yml'))[RAILS_ENV]

begin
	
	# This variable is added to differentiate multiple staging environments for reports archiving data in the s3 bucket
	$st_env_name = config["env_name"]

	$redshift = PG::Connection.connect_start(:host => config["host"], :dbname => config["dbname"], 
		:user => config["write"]["user"], :password => config["write"]["password"], :port => config["port"],
		:connect_timeout => config["connect_timeout"])

	$redshift_read = PG::Connection.connect_start(:host => config["host"], :dbname => config["dbname"], 
		:user => config["read"]["user"], :password => config["read"]["password"], :port => config["port"],
		:connect_timeout => config["connect_timeout"])
rescue
	puts "Redshift connection establishment failed."
end