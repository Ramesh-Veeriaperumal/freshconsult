class LaunchPartyActionWorker < BaseWorker
  include Sidekiq::Worker
  sidekiq_options queue: :launch_party_actions, retry: 0,  failures: :exhausted

  Dir[Rails.root.join('lib', 'launch_party', '*.rb')].each { |file| require(file) if File.exist?(file) }

  TYPE = [:launch, :rollback]

  def perform(args)
    args.symbolize_keys!
    account_id = args[:account_id]
    begin
      features = args[:features]
      features.each do |each_feature|
        each_feature.symbolize_keys!
        key = (TYPE & each_feature.keys).first
        feature_class_name = FeatureClassMapping.get_feature_class(each_feature[key].to_s)
        invoke_callbacks(feature_class_name, key, account_id, each_feature[key]) if feature_class_name
        central_lp_class_name = FeatureClassMapping.get_central_launchparty_class(each_feature[key].to_s)
        invoke_callbacks(central_lp_class_name, key, account_id, each_feature[key]) if central_lp_class_name && lp_central_publish?(args[:signup_in_progress], each_feature[key].to_s)
        Rails.logger.info "LaunchPartyActionWorker :: Processing Done :: #{account_id}"
      end
    rescue => e
      logger.info "Error when executing the launch party, args #{args.inspect}, error #{e.inspect}"
    end
  end

  private

    def invoke_callbacks(class_name, key, account_id, feature_name)
      method_name = :"on_#{key}"
      logger.info "Launch party callback class name for account_id #{account_id} is #{class_name}"
      feature_class_instance = class_name.constantize.new rescue nil
      if feature_class_instance && feature_class_instance.respond_to?(method_name.to_sym)
        feature_class_instance.safe_send('feature_name=', feature_name.first.to_sym)
        feature_class_instance.safe_send(method_name, account_id)
      end
    end

    def lp_central_publish?(is_signup, feature_name)
      !is_signup || Account::CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES.fetch(feature_name.to_sym, true)
    end
end
