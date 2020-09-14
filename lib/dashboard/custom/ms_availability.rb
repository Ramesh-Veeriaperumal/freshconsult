# frozen_string_literal: true

class Dashboard::Custom::MSAvailability < Dashboards
  CONFIG_FIELDS = [:queue_id].freeze
  CACHE_EXPIRY = 60

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods
  end
end
