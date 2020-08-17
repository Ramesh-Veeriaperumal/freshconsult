module Ember
  class AgentPreferencesValidation < ApiValidation
    attr_accessor :shortcuts_enabled, :shortcuts_mapping, :notification_timestamp, :show_onBoarding, :falcon_ui,
                  :undo_send, :focus_mode, :search_settings, :field_service, :show_loyalty_upgrade, :show_monthly_to_annual_notification

    validates :shortcuts_enabled, data_type: { rules: 'Boolean' }

    validates :shortcuts_mapping,
              data_type: { rules: Array },
              array: {
                data_type: { rules: Hash }
              }

    validates :notification_timestamp, date_time: { allow_nil: true }

    validates :show_onBoarding, data_type: { rules: 'Boolean' }

    validates :show_loyalty_upgrade, data_type: { rules: 'Boolean' }

    validates :show_monthly_to_annual_notification, data_type: { rules: 'Boolean' }

    validates :falcon_ui, data_type: { rules: 'Boolean' }

    validates :undo_send, data_type: { rules: 'Boolean' }

    validates :focus_mode, data_type: { rules: 'Boolean' }

    validates :field_service,
              data_type: { rules: Hash },
              hash: {
                dismissed_sample_scheduling_dashboard: { data_type: { rules: 'Boolean' } }
              }

    validates :search_settings,
              data_type: { rules: Hash },
              hash: {
                tickets: {
                  data_type: { rules: Hash },
                  hash: {
                    include_subject: { data_type: { rules: 'Boolean' } },
                    include_description: { data_type: { rules: 'Boolean' } },
                    include_other_properties: { data_type: { rules: 'Boolean' } },
                    include_notes: { data_type: { rules: 'Boolean' } },
                    include_attachment_names: { data_type: { rules: 'Boolean' } }
                  }
                }
              }

    def initialize(request_params, item)
      super(request_params, item)
    end
  end
end
