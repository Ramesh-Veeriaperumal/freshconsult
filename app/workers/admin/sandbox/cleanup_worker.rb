class Admin::Sandbox::CleanupWorker < BaseWorker
  include Sync::Constants

  sidekiq_options queue: :sandbox_cleanup, retry: 0, backtrace: true, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    master_account_id = args[:master_account_id]
    sandbox_account_id = args[:sandbox_account_id]
    Rails.logger.info("Starting Sandbox Cleanup :: Master: #{master_account_id} :: Sandbox: #{sandbox_account_id}")
    client = Sync::GitClient.new("#{GIT_ROOT_PATH}/#{master_account_id}")
    client.remove_remote_branch(master_account_id.to_s)
    client.remove_remote_branch(sandbox_account_id.to_s)
  rescue StandardError => e
    Rails.logger.error("SANDBOX CLEANUP EXCEPTION :: Account: #{master_account_id} :: Sandbox Account: #{sandbox_account_id}  \n#{e.message}\n#{e.backtrace[0..20].inspect}")
    NewRelic::Agent.notice_error(e, description: "SANDBOX CLEANUP EXCEPTION :: Account: #{master_account_id} :: Sandbox Account: #{sandbox_account_id}")
  end
end
