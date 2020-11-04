# frozen_string_literal: true

module CronWebhooks
  class SuspendAccountWebhookWorker < CronWebhooks::CronWebhookWorker
    sidekiq_options queue: :cron_suspended_accounts, retry: 0, dead: true, backtrace: 25, failures: :exhausted

    include CronWebhooks::Constants
    include Redis::RedisKeys
    include Redis::OthersRedis

    SUSPENSION_BASE_DATE = "'2019-01-01'"
    DEFAULT_BATCH_SIZE_TO_DELETE = 1000
    ACCOUNT_MAX_DELETION_ATTEMPT_COUNT = 10
    WORKER_STOP_KEY = 'SUSPENDED_ACCOUNT_CLEAN_UP_WORKER_STOP'
    ACCOUNTS_SKIP_LIST_KEY = 'SUSPENDED_ACCOUNT_CLEAN_UP_SKIP_LIST'
    BATCH_SIZE_TO_DELETE_KEY = 'SUSPENDED_ACCOUNT_CLEAN_UP_BATCH_SIZE'
    ACCOUNTS_SUSPENDED_BASE_DATE_KEY = 'ACCOUNTS_SUSPENDED_FROM_DATE'

    def perform(args)
      perform_block(args) do
        init
        perform_deletion
      end
    end

    private

      def init
        @dryrun = dry_run_mode?(@args[:mode])
        @start_time = Time.current
        @deleted_accounts = []
        @shards = ActiveRecord::Base.shard_names
        @processing_accounts = {}
        @shards.each { |sh| @processing_accounts[sh] = { account_id: 0, attempt_count: 0 } }
        @account_skip_list = get_all_members_in_a_redis_set(ACCOUNTS_SKIP_LIST_KEY).to_set
        @base_date = get_others_redis_key(ACCOUNTS_SUSPENDED_BASE_DATE_KEY) || SUSPENSION_BASE_DATE
      end

      def perform_deletion
        Rails.logger.info('Suspended account deletion webhook worker started.')
        return 0 if stop_execution?

        while @shards.present?
          @shards.each do |shard_name|
            Sharding.run_on_shard(shard_name) do
              begin
                account = fetch_next_account_from_shard(shard_name)
                next unless account

                account.make_current
                delete_account_on_shard(account, shard_name)

                return 0 if stop_execution?
              rescue StandardError => e
                Rails.logger.info("SuspendAccountWebhookWorker Exception while processing account - #{account.id} --- #{e.inspect}")
              ensure
                Account.reset_current_account
              end
            end
          end
        end
      rescue StandardError => e
        Rails.logger.info "SuspendAccountWebhookWorker StandardError - #{e.message} :: #{e.backtrace}"
        raise e
      ensure
        time_taken = Time.at((@start_time - Time.current).to_i.abs).utc.strftime('%H:%M:%S')
        account_ids = @deleted_accounts.map { |h| h[:account] }
        Rails.logger.info("successfully enqueued #{@deleted_accounts.size} jobs for deletion in #{time_taken}. Deleted Accounts - #{account_ids.inspect}")
        @deleted_accounts.each_slice(250).each { |del_acc| Rails.logger.info("Deleted account details :: #{del_acc.inspect}") }
      end

      def fetch_next_account_from_shard(shard_name)
        processing_account_id = @processing_accounts[shard_name][:account_id]
        account = Account.joins(:subscription).where("accounts.id >= #{processing_account_id} AND subscriptions.state = 'suspended' AND subscriptions.updated_at < #{@base_date}").order('accounts.id asc').limit(1).first
        if account.nil?
          delete_shard(shard_name)
          Rails.logger.info("No suspended account present on shard #{shard_name}")
        elsif @account_skip_list.include?(account.id.to_s)
          Rails.logger.info "Skip list account found - #{account.id}"
          @processing_accounts[shard_name] = { account_id: account.id + 1, attempt_count: 0 }
          account = nil
        elsif @processing_accounts[shard_name][:account_id] == account.id
          if @processing_accounts[shard_name][:attempt_count] > max_retry_count
            Rails.logger.info "Already processing account exceeds max retry count - #{account.id}"
            @processing_accounts[shard_name] = { account_id: account.id + 1, attempt_count: 0 }
            account = nil
          elsif (@processing_accounts[shard_name][:attempt_count]).zero?
            @processing_accounts[shard_name][:attempt_count] = 1 + @processing_accounts[shard_name][:attempt_count]
          else
            Rails.logger.info "Already processing account found - #{account.id}"
            @processing_accounts[shard_name][:attempt_count] = 1 + @processing_accounts[shard_name][:attempt_count]
            account = nil
          end
        else
          @processing_accounts[shard_name] = { account_id: account.id, attempt_count: 1 }
        end
        account
      end

      def delete_account_on_shard(account, shard_name)
        if shard_mapping_exist?(account.id, shard_name)
          job_id = AccountCleanup::DeleteAccount.perform_async(account_id: account.id) unless @dryrun
          @deleted_accounts << { account: account.id, shard: shard_name, rebalanced: false }
        else
          job_id = AccountCleanup::RebalancedAccountDeleteWorker.perform_async(account_id: account.id, shard_name: shard_name) unless @dryrun
          @deleted_accounts << { account: account.id, shard: shard_name, rebalanced: true }
        end
        subscription = account.subscription
        Rails.logger.info "Deleting suspended account - #{account.id} with subscription - #{subscription.inspect}. Total deleted #{@deleted_accounts.size}, job id #{job_id}."
      end

      def shard_mapping_exist?(account_id, shard_name)
        ShardMapping.where(account_id: account_id, shard_name: shard_name).exists?
      end

      def stop_execution?
        if @deleted_accounts.size >= batch_size || redis_key_exists?(WORKER_STOP_KEY)
          Rails.logger.info("Stopped execution after enqueuing  #{@deleted_accounts.size} accounts.")
          return true
        end
        false
      end

      def delete_shard(shard_name)
        @shards.delete(shard_name)
      end

      def batch_size
        (get_others_redis_key(BATCH_SIZE_TO_DELETE_KEY) || DEFAULT_BATCH_SIZE_TO_DELETE).to_i
      end

      def max_retry_count
        @dryrun ? 0 : ACCOUNT_MAX_DELETION_ATTEMPT_COUNT
      end
  end
end
