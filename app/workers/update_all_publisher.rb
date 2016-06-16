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
    
    # Move feature check inside if multiple subscribers added
    
    args[:klass_name].constantize.where(account_id: Account.current.id, id: args[:ids]).each do |record|
      #=> For search v2

      record.sqs_manual_publish_without_feature_check if subscribers.include?('search')  if Account.current.try(:features?, :es_v2_writes)
      record.count_es_manual_publish if record.respond_to?(:count_es_manual_publish) and Account.current.features?(:count_es_writes)
      # Add other subscribers here if needed like reports, etc.
    end
  end

end