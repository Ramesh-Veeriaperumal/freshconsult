class FeatureClassMapping
  FEATURE_TO_CLASS = {
    supervisor_multi_select: 'SupervisorMultiSelect',
    advanced_ticket_scopes: 'AdvancedTicketScope'
  }.freeze

  def self.get_class(feature_name)
    feature_name = feature_name.to_sym if feature_name
    FEATURE_TO_CLASS[feature_name]
  end
end
