class InternalService::FreshopsOperations < BaseWorker
  include Sidekiq::Worker
  include InternalService::FreshopsUtils
  sidekiq_options queue: :freshops_service, retry: 0,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    @account = Account.current
    Rails.logger.info("In FreshopsOperations worker :: #{args.inspect}")
    safe_send(%(trigger_#{args[:action_type]}_service), args) if respond_to?("trigger_#{args[:action_type]}_service", args)
  end

  private

    def trigger_enable_old_ui_service(*)
      return if @account.nil?
      return unless @account.disable_old_ui_enabled?
      invoke_enable_old_ui
    end

    def trigger_daypass_export_service(args)
      return if @account.nil?
      export_daypass_usage(args[:export_duration], args[:user_email])
    end
end