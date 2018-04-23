# This worker class is for publishing update_all updates to Subscribers
#
class UpdateAllPublisher
  include Sidekiq::Worker
  
  sidekiq_options :queue => :update_all_callbacks, :retry => 0, :backtrace => true, :failures => :exhausted
  
  def perform(args)
    args.symbolize_keys!
    model_name    = args[:klass_name].demodulize.tableize.downcase.singularize
    exchange_name = RabbitMq::Constants::MODEL_TO_EXCHANGE_MAPPING[model_name]
    subscribers   = (RabbitMq::Keys.const_get("#{exchange_name.upcase}_SUBSCRIBERS") rescue [])
    
    esv2_enabled      = Account.current.features_included?(:es_v2_writes)
    count_es_enabled  = Account.current.features?(:countv2_writes)
    args[:options]  ||= {}
    options           = args[:options].deep_symbolize_keys
    # Move feature check inside if multiple subscribers added
    manual_publish = esv2_enabled || count_es_enabled || options[:manual_publish].present?
    args[:klass_name].constantize.where(account_id: Account.current.id, id: args[:ids]).each do |record|
      if manual_publish
        #=> For search v2
        record.sqs_manual_publish_without_feature_check if esv2_enabled and subscribers.include?('search')
        record.count_es_manual_publish if count_es_enabled and record.respond_to?(:count_es_manual_publish)
        key = RabbitMq::Constants::RMQ_REPORTS_TICKET_KEY
        if options[:reason].present?
          record.misc_changes = options[:reason]
          key = RabbitMq::Constants::RMQ_GENERIC_TICKET_KEY
        end
        # Add other subscribers here if needed like reports, etc.
      end
      rmq_options = options[:manual_publish] ? ["update", key, {:manual_publish => true}] : []
      central_publish_options = { model_changes: (args[:updates] || {}).inject({}) {|h, (k, v)| h[k] = ["*", v]; h} }
      central_publish_options.merge!(misc_changes: options[:reason]) if options[:reason].present?
      record.manual_publish(rmq_options, [:update, central_publish_options], true)
    end
  end

end