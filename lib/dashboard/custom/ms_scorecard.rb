# frozen_string_literal: true

class Dashboard::Custom::MSScorecard < Dashboards
  CONFIG_FIELDS = [:view].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_view(source, view)
      source == Dashboard::Custom::CustomDashboardConstants::SOURCES[:freshchat] ? view.to_i.positive? : false
    end
  end
end
