# frozen_string_literal: true

class Dashboard::Custom::MSCallTrend < Dashboards
  CONFIG_FIELDS = [:view, :queue_id, :time_type].freeze
  FRESHCALLER_VIEWS = {
    1 => 'Total calls',
    2 => 'Total incoming calls',
    3 => 'Total outgoing calls',
    4 => 'Total missed calls',
    5 => 'Total incoming missed calls',
    6 => 'Total outgoing missed calls'
  }.freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_view(source, view)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshcaller] ? FRESHCALLER_VIEWS[view.to_i].present? : false
    end
  end
end
