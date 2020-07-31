# frozen_string_literal: true

module AccountCleanup
  class OldSuspendedAccountsWorker < AccountCleanup::DeleteAccount
    def perform(args)
      Account.reset_current_account
      shard_name = args['shard_name']
      account_id = args['account_id']
      Sharding.run_on_shard(shard_name) do
        account = Account.find account_id
        account.make_current
        return unless account.subscription.suspended?

        super(args)
      end
    rescue StandardError => e
      msg = "Unable to perform old suspended account deletion for Shard: #{shard_name} and Account: #{account_id}"
      Rails.logger.info msg
      NewRelic::Agent.notice_error(e, description: msg)
    ensure
      Account.reset_current_account
    end
  end
end
