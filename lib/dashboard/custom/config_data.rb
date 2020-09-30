module Dashboard::Custom
  module ConfigData
    include ::Dashboard::Custom::CustomDashboardConstants

    CONFIG_ATTRIBUTES = SCORECARD_ATTRIBUTES | BAR_CHART_ATTRIBUTES | TICKET_TREND_CARD_ATTRIBUTES | TIME_TREND_CARD_ATTRIBUTES | SLA_TREND_CARD_ATTRIBUTES | CSAT_ATTRIBUTES | LEADERBOARD_ATTRIBUTES | MS_AVAILABILITY_ATTRIBUTES | MS_TIME_TREND_ATTRIBUTES | MS_SLA_TREND_ATTRIBUTES | MS_CALL_TREND_ATTRIBUTES | OMNI_CONFIG_ATTRIBUTES | MS_SCORECARD_ATTRIBUTES | MS_BAR_CHART_ATTRIBUTES | MS_CSAT_ATTRIBUTES

    CONFIG_ATTRIBUTES.each do |attribute|
      define_method("#{attribute}=") do |updated_value|
        merge_config_data(attribute => updated_value)
      end
    end

    OMNI_CONFIG_ATTRIBUTES.each do |attribute|
      define_method(attribute.to_s) do
        config_data[attribute]
      end
    end

    def ticket_filter_id=(updated_value)
      default_filter_info, custom_filter_info = Helpdesk::Filters::CustomTicketFilter::DEFAULT_FILTERS.key?(updated_value) || ::Admin::AdvancedTicketing::FieldServiceManagement::Constant::FSM_TICKET_FILTERS.include?(updated_value) ? [updated_value, nil] : [nil, updated_value]
      merge_config_data(ticket_filter_id: default_filter_info)
      updated_value = custom_filter_info
      super
    end

    def ticket_filter_id
      return config_data[:ticket_filter_id] if config_data[:ticket_filter_id]

      super
    end

    private

      def merge_config_data(updated_config)
        self.config_data = HashWithIndifferentAccess.new(config_data.merge(updated_config))
        ticket_filter_id
      end
  end
end
