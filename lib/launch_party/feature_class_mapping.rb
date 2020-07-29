class FeatureClassMapping
  FEATURE_TO_CLASS = {
    supervisor_multi_select: 'SupervisorMultiSelect',
    advanced_ticket_scopes: 'AdvancedTicketScope'
  }.freeze

  LP_FEATURE_MAPPING = Account::CENTRAL_PUBLISH_LAUNCHPARTY_FEATURES.collect { |lpfeature| [lpfeature, 'CentralPublishLaunchpartyFeatures'] }.to_h
  FEATURE_TO_CLASS_WITH_CENTRAL_FEATURE = FEATURE_TO_CLASS.merge(LP_FEATURE_MAPPING).freeze

  def self.get_class(feature_name)
    feature_name = feature_name.to_sym if feature_name
    FEATURE_TO_CLASS_WITH_CENTRAL_FEATURE[feature_name]
  end
end
