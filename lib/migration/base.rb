module Migration
  class Base
    include Redis::DisplayIdRedis
    include Redis::OthersRedis
    include Redis::RedisKeys
    
    attr_accessor :options

    RETRY_LIMIT = 3

    def initialize(options = {})
      @options = options
      @account_id = options[:account_id]
      @redis_key = options[:redis_key]
    end

    private

      def log(text)
        Rails.logger.debug "#{Thread.current[:migration_klass]} #{text}"
      end

      def account
        Account.current
      end

      def perform_migration
        Sharding.select_shard_of(@account_id) do
          Sharding.run_on_slave do
            account = Account.find(@account_id).make_current
            verified = false
            retry_count = 1
            loop do
              yield
              verified = verify_migration
              break if verified || retry_count > RETRY_LIMIT
              retry_count += 1
            end
            add_member_to_redis_set(@redis_key, account.id) unless verified
          end
        end
      rescue
        Account.reset_current_account
      end
  end
end
