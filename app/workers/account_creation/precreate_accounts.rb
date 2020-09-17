module AccountCreation
  class PrecreateAccounts < BaseWorker
    sidekiq_options queue: :precreate_accounts_create, retry: 3, failures: :exhausted

    include Redis::RedisKeys
    include Redis::OthersRedis
    include AccountsHelper

    def perform(args)
      args.symbolize_keys!
      number_of_accounts = args[:precreate_account_count] || 1
      shard_name = args[:shard_name]
      Sharding.run_on_shard(shard_name) do
        number_of_accounts.times do
          precreate_accounts(shard_name)
        end
      end
    rescue StandardError => e
      Rails.logger.error "Exception while precreating accounts \
        acc_id: #{Account.current.try(:id)}, args: #{args.inspect}, error message: \
        #{e.message}, error: #{e.backtrace.join('\n')}"
      NewRelic::Agent.notice_error(e, custom_params: { description: "Error occoured while creating precreated accounts. args: #{args.inspect}, error message: #{e.message}, error: #{e.backtrace.join('\n')}" })
      raise e
    rescue ActiveRecord::RecordNotFound, ActiveRecord::AdapterNotSpecified, ShardNotFound => e
      Rails.logger.error "Exception while precreating accounts #{e.inspect}"
    ensure
      Account.reset_current_account
    end

    private

      def precreate_accounts(shard_name)
        Account.reset_current_account
        signup = Signup.new(precreated_account_signup_params)
        signup.account.is_anonymous_account = true
        signup.save!
        signup.account.reload
        signup.account.account_additional_settings.mark_account_as_anonymous(true)
        set_others_redis_lpush(format(PRECREATED_ACCOUNTS_SHARD, current_shard: shard_name), signup.account.id)
      rescue StandardError => e
        raise e
      end
  end
end
