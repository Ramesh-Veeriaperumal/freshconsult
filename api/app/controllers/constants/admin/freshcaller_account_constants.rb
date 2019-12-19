module Admin::FreshcallerAccountConstants
  VALIDATION_CLASS = 'Admin::FreshcallerAccountValidation'.freeze
  LINK_FIELDS = %w[url email password].freeze
  UPDATE_FIELDS = %w[agent_ids].freeze
  UPDATE_ARRAY_FIELDS = %w[agent_ids].freeze
end
