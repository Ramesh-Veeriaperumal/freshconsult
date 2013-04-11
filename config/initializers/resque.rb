require 'resque/server'
# require 'resque-retry'
# require 'resque-retry/server'
# require 'resque/status_server'
# require 'resque/job_with_status'
require 'resque/failure/multiple'
require 'resque/failure/redis'

Dir[File.join(Rails.root, 'app', 'jobs', '*.rb')].each { |file| require file }

config = YAML::load_file(File.join(RAILS_ROOT, 'config', 'redis.yml'))[Rails.env]

if config
	Resque.redis = Redis.new(:host => config["host"], :port => config["port"])
end

Resque::Server.use Rack::Auth::Basic do |username, password|
  username == 'freshdesk'
  password == 'USD40$'
end

# Resque::Plugins::Status::Hash.expire_in = (24 * 60 * 60) # 24hrs in seconds

# Exclude sending actual emails in these environments
#Resque::Mailer.excluded_environments = [:test, :cucumber, :development]

# Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
# Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression