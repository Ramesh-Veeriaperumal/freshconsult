# frozen_string_literal: true

class Dashboard::Custom::MSCsat < Dashboards
  CONFIG_FIELDS = [:group_ids, :date_type].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_date_type(source, date_type)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? DATE_FIELDS_MAPPING[date_type.to_i].present? : false
    end
  end
end
