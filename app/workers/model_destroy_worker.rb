# This worker simply destroy the model object passed to it. For cases where we need to do a delayed destroy we can use this.
class ModelDestroyWorker < BaseWorker
  sidekiq_options queue: :model_destroy, retry: 0,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    raise ArgumentError, "args, association_with_account can't be empty" if args.blank? || args[:association_with_account].blank?

    Account.current.safe_send(args[:association_with_account]).find(args[:id]).destroy
  rescue StandardError => e
    Rails.logger.error "Issue in DelayedDestroyWorker, args: #{args.inspect} message: #{e.message}"
    options = { custom_params: { description: "Issue in DelayedDestroyWorker, message: #{e.message}", account_id: Account.current.try(:id), args: args } }
    NewRelic::Agent.notice_error(e, options)
    raise e # To show up in the failed jobs queue.
  end
end
