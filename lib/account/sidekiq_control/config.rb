module Account::SidekiqControl
  class Config
    ROUTE_CONFIG = 'route_config'.freeze
    extend MonitorMixin
    class << self
      # To reroute a worker add the worker to reroute first account.route_add_workers(default, ['Namespace::Hardworker'])
      #
      # To reroute within namespace you can only specify namespace alone
      # Account::SidekiqControl::Config::route_redis_setting(['Namespace::Hardworker'], "namespace" => "reroute_test")
      #
      # To reroute a worker to another redis you can do this
      # Account::SidekiqControl::Config::route_redis_setting(['Namespace::Hardworker'], {"host" => "localhost", "namespace" => "reroute_test", "password" => "root", "port" => "32768"})
      def route_redis_setting(workers = [], config = {})
        config_redefined = DUP_SIDEKIQ_CONFIG.merge(config)
        Sidekiq.redis do |redis|
          workers.each do |worker_name|
            redis.mapped_hmset(route_config_key(worker_name), config_redefined)
          end
        end
        validate_redis_connection(workers.first) if workers.present?
      end

      def via_redis_pool(worker_name)
        @config ||= {}
        @via_redis_pool ||= {}
        @config[worker_name] ||= Sidekiq.redis do |redis|
          redis.hgetall(route_config_key(worker_name))
        end
        synchronize do
          @via_redis_pool[worker_name] ||= ConnectionPool.new do
            client = Redis.new(@config[worker_name])
            Redis::Namespace.new(@config[worker_name]['namespace'], redis: client) if @config[worker_name]['namespace'].present?
          end
        end
      end

      def remove_route_redis_setting(workers = [])
        @config         = {}
        @via_redis_pool = {}
        Sidekiq.redis do |redis|
          workers.each do |worker_name|
            redis.del(route_config_key(worker_name))
          end
        end
      end

      def route_config_key(worker_name)
        "#{ROUTE_CONFIG}::#{worker_name}"
      end

      private

        def validate_redis_connection(worker_name)
          via_redis_pool(worker_name)
          @via_redis_pool[worker_name].with { |con| con.set('ping', 'pong', ex: 5) }
        end
    end
  end
end
