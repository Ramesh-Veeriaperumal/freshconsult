class Admin::CloneWorker < BaseWorker

  sidekiq_options :queue => :clone, :retry => 0, :backtrace => true, :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    ::Sync::Workflow.new(args[:clone_account_id], false, args[:account_id]).provision_staging_instance
    rescue  => e
      Rails.logger.error("Clone Exception in account: #{args[:account_id]} Clone account: #{args[:clone_account_id]}  \n#{e.message}\n#{e.backtrace.join("\n\t")}")
      NewRelic::Agent.notice_error(e, {:description=> "Clone Error in Account: #{args[:account_id]}"})
  end
end
