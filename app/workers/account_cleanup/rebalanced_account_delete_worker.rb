# frozen_string_literal: true

module AccountCleanup
  class RebalancedAccountDeleteWorker < AccountCleanup::DeleteAccount
    include FreshdeskCore::Model

    def perform(args)
      Account.reset_current_account
      @shard_name = args['shard_name']
      account_id = args['account_id']
      Sharding.run_on_shard(@shard_name) do
        account = Account.find account_id
        account.make_current
        return unless account.subscription.suspended?

        perform_delete_table_data(account_id)
      end
    rescue StandardError => e
      msg = "Unable to perform rebalanced account deletion for Shard: #{@shard_name} and Account: #{account_id} --- #{e.inspect}"
      Rails.logger.info msg
      NewRelic::Agent.notice_error(e, description: msg)
    ensure
      Account.reset_current_account
    end

    private

      def perform_delete_table_data(account_id)
        @continue_account_destroy_from ||= 0
        account_destroy_functions = [
          -> { delete_data_from_tables(account_id) },
          -> { delete_data_from_tables_without_id(account_id) },
          -> { delete_data_from_account_table(account_id) }
        ]

        account_destroy_functions.slice(@continue_account_destroy_from,
                                        account_destroy_functions.size).each_with_index do |function, index|
          begin
            function.call
          rescue ReplicationLagError => e
            @continue_account_destroy_from += index
            return rerun_after(account_id, e.lag)
          end
        end
      end

      def delete_data_from_account_table(account_id)
        delete_query = ['delete from accounts where id = %s;', account_id]
        sanitized_delete_query = ActiveRecord::Base.safe_send(:sanitize_sql_array, delete_query)
        ActiveRecord::Base.connection.execute(sanitized_delete_query)
      end

      def rerun_after(account_id, lag = 0)
        Rails.logger.debug("Warning: Freno: AccountCleanup::RebalancedAccountDeleteWorker: @continue_account_destroy_from: #{@continue_account_destroy_from}, replication lag: #{lag} secs :: shard :: #{@shard_name} :: account :: #{account_id}")
        AccountCleanup::RebalancedAccountDeleteWorker.perform_in(lag.seconds.from_now, account_id: account_id, shard_name: @shard_name,
                                                                                       continue_account_destroy_from: @continue_account_destroy_from)
      end
  end
end
