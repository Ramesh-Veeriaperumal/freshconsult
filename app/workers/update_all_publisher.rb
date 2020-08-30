# This worker class is for publishing update_all updates to Subscribers
#
class UpdateAllPublisher
  include Sidekiq::Worker
  
  sidekiq_options :queue => :update_all_callbacks, :retry => 0, :failures => :exhausted
  
  def perform(args)
    args.symbolize_keys!
    model_name    = args[:klass_name].demodulize.tableize.downcase.singularize
    exchange_name = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
    subscribers   = (RabbitMq::Keys.const_get("#{exchange_name.upcase}_SUBSCRIBERS") rescue [])
    
    esv2_enabled      = Account.current.features_included?(:es_v2_writes)
    args[:options]  ||= {}
    options           = args[:options].deep_symbolize_keys
    Account.current.users.find(options[:doer_id]).make_current if options[:doer_id].present?
    # Move feature check inside if multiple subscribers added
    args[:klass_name].constantize.where(account_id: Account.current.id, id: args[:ids]).each do |record|
      #=> For search v2
      record.sqs_manual_publish_without_feature_check if esv2_enabled && subscribers.include?('search')
      record.count_es_manual_publish if record.respond_to?(:count_es_manual_publish)
      next unless options[:manual_publish]
      key = RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY
      if options[:reason].present?
        record.misc_changes = options[:reason]
        key = RabbitMq::Constants::RMQ_GENERIC_TICKET_KEY
      end
      key = options[:routing_key] if options[:routing_key].present?
      rmq_options = ['update', key, { manual_publish: true }]
      central_publish_options = {}
      central_publish_options[:model_changes] = options[:model_changes].presence || (args[:updates] || {}).inject({}) { |h, (k, v)| h[k] = ['*', v]; h }
      central_publish_options.merge!(misc_changes: options[:reason]) if options[:reason].present?
      record.manual_publish(rmq_options, [:update, central_publish_options], true)
      # Add other subscribers here if needed like reports, etc./
    end
  ensure
    options[:doer_id].present? && User.reset_current_user
  end
end
