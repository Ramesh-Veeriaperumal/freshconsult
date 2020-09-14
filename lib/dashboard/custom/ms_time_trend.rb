# frozen_string_literal: true

class Dashboard::Custom::MSTimeTrend < Dashboards
  CONFIG_FIELDS = [:metric, :queue_id, :time_type].freeze
  CACHE_EXPIRY = 60
  FRESHCALLER_METRICS = {
    1 => 'Average time to answer',
    2 => 'Average wait time',
    3 => 'Longest wait time',
    4 => 'Average handle time',
    5 => 'Average talk time'
  }.freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_metric(source, metric)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshcaller] ? FRESHCALLER_METRICS[metric.to_i].present? : false
    end
  end
end
