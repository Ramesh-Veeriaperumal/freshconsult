# frozen_string_literal: true

class Dashboard::Custom::MSTimeTrend < Dashboards
  CONFIG_FIELDS = [:metric, :queue_id, :time_type, :computation, :group_ids, :date_range].freeze
  FRESHCALLER_METRICS = {
    1 => 'Average time to answer',
    2 => 'Average wait time',
    3 => 'Longest wait time',
    4 => 'Average handle time',
    5 => 'Average talk time'
  }.freeze
  FRESHCHAT_COMPUTATIONS = {
    1 => 'Median',
    2 => 'Average',
    3 => 'Percentile'
  }.freeze
  FRESHCHAT_METRICS = {
    1 => 'First Response time',
    2 => 'Response Time',
    3 => 'Resolution Time',
    4 => 'Wait time'
  }.freeze

  FRESHCHAT_DATE_RANGE = [0, 15, 30, 60, 120, 360].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_metric(source, metric)
      case source
      when Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshcaller]
        FRESHCALLER_METRICS[metric.to_i].present?
      when Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat]
        FRESHCHAT_METRICS[metric.to_i].present?
      else
        false
      end
    end

    def validate_computation(source, computation)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? FRESHCHAT_COMPUTATIONS[computation.to_i].present? : computation.blank?
    end

    def validate_date_range(source, date_range)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? FRESHCHAT_DATE_RANGE.include?(date_range.to_i) : date_range.blank?
    end
  end
end
