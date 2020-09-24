module Admin::FreshcallerAccountConstants
  VALIDATION_CLASS = 'Admin::FreshcallerAccountValidation'.freeze
  LINK_FIELDS = %w[url email password].freeze
  AUTOMATIC_TICKET_CREATION_SETTINGS = [automatic_ticket_creation: %w[missed_calls abandoned_calls connected_calls]].freeze
  SETTINGS_FIELDS = [settings: AUTOMATIC_TICKET_CREATION_SETTINGS].freeze
  UPDATE_FIELDS = %w[agent_ids] | SETTINGS_FIELDS
  UPDATE_ARRAY_FIELDS = %w[agent_ids].freeze
end
