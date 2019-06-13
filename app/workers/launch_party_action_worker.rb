class LaunchPartyActionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :launch_party_actions, retry: 0,  failures: :exhausted

  require 'launch_party/feature_class_mapping'
  require 'launch_party/supervisor_multi_select'

  TYPE = [:launch, :rollback]

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    begin
      features = args[:features]
      features.each do |each_feature|
        each_feature.symbolize_keys!
        key = (TYPE & each_feature.keys).first
        class_name = FeatureClassMapping.get_class(each_feature[key].to_s)
        method_name = :"on_#{key}"
        logger.info "Launch party callback class name for account_id #{account_id} is #{class_name}"
        feature_class_instance = class_name.constantize.new rescue nil
        feature_class_instance.send(method_name, account_id) if feature_class_instance && feature_class_instance.respond_to?(method_name.to_sym)
      end
    rescue => e
      logger.info "Error when executing the launch party, args #{args.inspect}, error #{e.inspect}"
    end
  end
end
