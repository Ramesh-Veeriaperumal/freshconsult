class Admin::Sandbox::DataToFileWorker < BaseWorker
  include SandboxHelper

  sidekiq_options queue: :sandbox_data_to_file, retry: 0, backtrace: true, failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    committer = {
      name: User.current.name,
      email: User.current.email
    }
    Rails.logger.info " **** [SANDBOX]  Starting config_to_file for account: #{@account.id} **** "
    Sharding.select_shard_of(@account.id) do
      @job = @account.sandbox_job
      @job.mark_shard_as!(:maintenance)
      @job.mark_as!(:sync_from_prod)
      ::Sync::Workflow.new.sync_config_from_production(committer)
      # enqueue file_to_data worker unless clone. Hack for now to create clone.
      ::Admin::Sandbox::FileToDataWorker.perform_async unless args[:clone]
    end
    Rails.logger.info " **** [SANDBOX] Finished config_to_file for account: #{@account.id} **** "
  rescue StandardError => e
    Rails.logger.error("Sandbox Exception in account: #{@account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
    NewRelic::Agent.notice_error(e, description: "Sandbox Error in Account: #{@account.id}")
    @job.update_last_error(e, :build_error) if @job
    send_error_notification(e, @account)
  end
end
