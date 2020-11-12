class FeatureClassMapping
  FEATURE_TO_CLASS = {
    advanced_ticket_scopes: 'AdvancedTicketScope',
    ocr_to_mars_api: 'OcrToMarsApi',
    agent_statuses: 'AgentStatus',
    omni_business_calendar: 'ChannelFeatureSync'
  }.freeze

  LP_FEATURE_MAPPING = Account::CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES.keys.collect { |lpfeature| [lpfeature, 'CentralPublishLaunchpartyFeatures'] }.to_h

  def self.get_feature_class(feature_name)
    feature_name = feature_name.to_sym if feature_name
    FEATURE_TO_CLASS[feature_name]
  end

  def self.get_central_launchparty_class(feature_name)
    feature_name = feature_name.to_sym if feature_name
    LP_FEATURE_MAPPING[feature_name]
  end
end
