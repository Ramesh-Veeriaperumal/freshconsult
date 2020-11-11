# frozen_string_literal: true

module AccountCleanup
  class AccountDeleteWorker < AccountCleanup::DeleteAccount
    include FreshdeskCore::Model

    def perform(args)
      Account.reset_current_account
      @shard_name = args['shard_name']
      account_id = args['account_id']
      Rails.logger.debug "AccountCleanup::AccountDeleteWorker:: account_id - #{account_id}, shard_name - #{@shard_name}"
      Sharding.run_on_shard(@shard_name) do
        Account.find(account_id).make_current
        super
      end
    ensure
      Account.reset_current_account
    end

    private

      def rerun_after(lag, account_id)
        Rails.logger.debug("Warning: Freno: AccountCleanup::AccountDeleteWorker: @continue_account_destroy_from: #{@continue_account_destroy_from}, replication lag: #{lag} secs :: shard :: #{@shard_name} :: account :: #{account_id}")
        AccountCleanup::AccountDeleteWorker.perform_in(lag.seconds.from_now, account_id: account_id, shard_name: @shard_name,
                                                                             continue_account_destroy_from: @continue_account_destroy_from)
      end
  end
end
