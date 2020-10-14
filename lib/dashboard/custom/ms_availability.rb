# frozen_string_literal: true

class Dashboard::Custom::MSAvailability < Dashboards
  CONFIG_FIELDS = [:team_id, :group_ids].freeze

  class << self
    include Dashboard::Custom::OmniWidgetConfigValidationMethods

    def validate_team_id(source, team_id)
      source == SOURCES[:freshcaller] ? numeric?(team_id) && team_id.to_i >= ALL_GROUPS : team_id.blank?
    end

    def numeric?(check)
      true if Integer(check)
    rescue StandardError
      false
    end
  end
end
