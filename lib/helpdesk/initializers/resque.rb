require 'resque/server'
# require 'resque-retry'
# require 'resque-retry/server'
# require 'resque/status_server'
# require 'resque/job_with_status'
require 'resque/failure/multiple'
require 'resque/failure/redis'
require 'resque_scheduler'
require 'resque_scheduler/server'

Dir[File.join(Rails.root, 'app', 'jobs', '*.rb')].each { |file| require file }

config = YAML::load_file(File.join(Rails.root, 'config', 'redis.yml'))[Rails.env]

if config
	Resque.redis = Redis.new(:host => config["host"], :port => config["port"])
end

Resque::Server.use Rack::Auth::Basic do |username, password|
  username == 'freshdesk'
  password == 'USD40$'
end

Resque::Plugins::Status::Hash.expire_in = (7 * 24 * 60 * 60) # 1 week in seconds

# Exclude sending actual emails in these environments
#Resque::Mailer.excluded_environments = [:test, :cucumber, :development]

# Resque::Failure::MultipleWithRetrySuppression.classes = [Resque::Failure::Redis]
# Resque::Failure.backend = Resque::Failure::MultipleWithRetrySuppression

# Dirty hack to reduce the meta queries for each resque.
# http://ablogaboutcode.com/2012/03/08/reducing-metadata-queries-in-resque/
Resque.before_first_fork do
  Sharding.all_shards.each do |shard|
    Sharding.run_on_shard(shard) do
      ActiveRecord::Base.send(:subclasses).each do |model|
        next if model.abstract_class?
        begin
          ActiveRecord::Base.connection.schema_cache.columns_hash[model.table_name]
        rescue
        end
      end
    end
  end
end

# Resque.before_fork do
#   if defined?(GC)
#     t0 = Time.now
#     GC.start
#     puts "Out-Of-Bound GC finished in #{Time.now - t0} sec"
#   end
# end