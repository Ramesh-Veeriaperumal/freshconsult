class Admin::Sandbox::ConfigToFileWorker < BaseWorker
  include SandboxHelper

  sidekiq_options :queue => :sandbox_config_to_file, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    committer = {
        :name  => User.current.name,
        :email => User.current.email
    }
    Rails.logger.info " **** [SANDBOX]  Starting config_to_file for account: #{@account.id} **** "
    Sharding.select_shard_of(@account.id) do
      @job = @account.sandbox_job
      message   = "Storing Config #{Time.now.strftime("%H:%M:%S")}"
      @job.mark_shard_as!(:maintenance)
      @job.mark_as!(:sync_from_prod)
      ::Sync::Workflow.new.sync_config_from_production(committer, message)
      #enqueue file_to_config worker unless clone. Hack for now to create clone.
      ::Admin::Sandbox::FileToConfigWorker.perform_async unless args[:clone]
    end
    Rails.logger.info " **** [SANDBOX] Finished config_to_file for account: #{@account.id} **** "
  rescue  => e
    Rails.logger.error("Sandbox Exception in account: #{@account.id} \n#{e.message}\n#{e.backtrace.join("\n\t")}")
    NewRelic::Agent.notice_error(e, {:description=> "Sandbox Error in Account: #{@account.id}"})
    @job.update_last_error(e) if @job
    send_error_notification(e, @account)
  end
end
