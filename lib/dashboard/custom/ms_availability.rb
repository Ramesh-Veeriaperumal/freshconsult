# frozen_string_literal: true

class Dashboard::Custom::MSAvailability < Dashboards
  CONFIG_FIELDS = [:queue_id, :group_ids].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods
  end
end
