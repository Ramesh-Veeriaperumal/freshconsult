# frozen_string_literal: true

class Dashboard::Custom::MSBarChart < Dashboards
  CONFIG_FIELDS = [:group_ids, :representation].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_representation(source, representation)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? [NUMBER, PERCENTAGE].include?(representation.to_i) : false
    end
  end
end
