class LaunchPartyActionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :launch_party_actions, :retry => 0, :backtrace => true, :failures => :exhausted

  require 'launch_party/feature_class_mapping'
  require 'launch_party/supervisor_multi_select'

  def perform(args)
    args = args.symbolize_keys
    account_id = args[:account_id]
    if args[:rollback]
      class_name = FeatureClassMapping::FEATURE_TO_CLASS["#{args[:rollback]}".to_sym]
      method_name = 'on_rollback'
    elsif args[:launch]
      class_name = FeatureClassMapping::FEATURE_TO_CLASS["#{args[:launch]}".to_sym]
      method_name = 'on_launch'
    end
    logger.info class_name
    class_name = class_name.constantize rescue nil
    class_name.send(method_name, account_id) if class_name && class_name.respond_to?(method_name.to_sym)
  end
end