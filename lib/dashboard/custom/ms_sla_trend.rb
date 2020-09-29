# frozen_string_literal: true

class Dashboard::Custom::MSSlaTrend < Dashboards
  CONFIG_FIELDS = [:queue_id, :time_type].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods
  end
end
