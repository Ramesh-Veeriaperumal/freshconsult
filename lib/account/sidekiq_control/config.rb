module Account::SidekiqControl
  class Config
    ROUTE_CONFIG = 'route_config'.freeze
    extend MonitorMixin
    class << self
      # To reroute a worker add the worker to reroute first account.route_add_workers(default, ['Namespace::Hardworker'])
      #
      # To reroute within namespace you can only specify namespace alone Account::SidekiqControl::Config::route_redis_setting("namespace" => "reroute_test")
      #
      # To reroute a worker to another redis you can do this Account::SidekiqControl::Config::route_redis_setting("host" => "localhost", "namespace" => "reroute_test", "password" => "root", "port" => "32768")
      def route_redis_setting(config = {})
        config_redefined = DUP_SIDEKIQ_CONFIG.merge(config)
        Sidekiq.redis do |redis|
          redis.mapped_hmset(ROUTE_CONFIG, config_redefined)
        end
        validate_redis_connection
      end

      def via_redis_pool
        @config ||= Sidekiq.redis do |redis|
          redis.hgetall(ROUTE_CONFIG)
        end
        synchronize do
        @via_redis_pool ||= ConnectionPool.new do
            client = Redis.new(@config)
            Redis::Namespace.new(@config['namespace'], redis: client) if @config['namespace'].present?
          end
        end
      end

      def remove_route_redis_setting
        @config         = nil
        @via_redis_pool = nil
        Sidekiq.redis do |redis|
          redis.del(ROUTE_CONFIG)
        end
      end

      private

        def validate_redis_connection
          via_redis_pool
          @via_redis_pool.with { |con| con.set('ping', 'pong', ex: 5) }
        end
    end
  end
end
