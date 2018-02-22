class LaunchPartyActionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :launch_party_actions, retry: 0, backtrace: true, failures: :exhausted

  require 'launch_party/feature_class_mapping'
  require 'launch_party/supervisor_multi_select'

  def perform(args)
    args = args.deep_symbolize_keys
    account_id = args[:account_id]
    feature = args[:feature]
    if feature[:rollback]
      class_name = FeatureClassMapping.get_class(feature[:rollback].to_s)
      method_name = :on_rollback
    elsif feature[:launch]
      class_name = FeatureClassMapping.get_class(feature[:launch].to_s)
      method_name = :on_launch
    end
    logger.info "Launch party callback class name for account_id #{account_id} is #{class_name}"
    class_name = class_name.constantize rescue nil
    feature_class_instance = class_name.new if class_name
    feature_class_instance.safe_send(method_name, account_id) if feature_class_instance && feature_class_instance.respond_to?(method_name.to_sym)
  end
end
