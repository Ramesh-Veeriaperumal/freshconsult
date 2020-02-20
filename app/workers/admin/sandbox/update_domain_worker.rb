class Admin::Sandbox::UpdateDomainWorker < BaseWorker
  sidekiq_options queue: :update_url_in_sandbox, retry: 0, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    sandbox_account_id = args[:sandbox_account_id]
    Sharding.run_on_shard SANDBOX_SHARD_CONFIG do
      sandbox_account = Account.find(sandbox_account_id).make_current
      sandbox_additional_settings = sandbox_account.account_additional_settings.additional_settings
      (sandbox_additional_settings[:sandbox] ||= {})[:production_url] = args[:production_full_domain]
      sandbox_account.account_additional_settings.save!
    end
  rescue StandardError => error
    Rails.logger.error("Could'nt update production url in sandbox, for Sandbox Account: #{sandbox_account_id}")
    NewRelic::Agent.notice_error(error, description: "Production url update in sandbox error : #{sandbox_account_id}")
  ensure
    Account.reset_current_account
  end
end
