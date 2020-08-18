module Users
  module Preferences
    # Default settings for user preferences
    DEFAULTS_PREFERENCES = { 
      :agent_preferences => { 
        :shortcuts_enabled => true,
        :shortcuts_mapping => [],
        :notification_timestamp => nil,
        :show_onBoarding => true, 
        :show_loyalty_upgrade => false,
        :show_monthly_to_annual_notification => false,
        :falcon_ui => false,
        freshchat_token: nil,
        undo_send: false,
        focus_mode: false,
        field_service: { dismissed_sample_scheduling_dashboard: false },
        search_settings: {
          tickets: {
            include_subject: true,
            include_description: true,
            include_other_properties: true,
            include_notes: true,
            include_attachment_names: true,
            archive: true
          }
        }
        # Add new pref for agents here
      },
      :user_preferences => {
        # Add new pref for users here
        :was_agent => false,
        :agent_deleted_forever => false,
        :marked_for_hard_delete => false
      }
    }

    def merge_preferences=(pref = {})
      self.preferences = (self.preferences_without_defaults || {}).deep_merge(pref)
    end

    private

      def preferences_with_defaults
        preferences_with_defaults = DEFAULTS_PREFERENCES.deep_dup.with_indifferent_access
        preferences_with_defaults = preferences_with_defaults.deep_merge(self.preferences_without_defaults.with_indifferent_access || {})
        preferences_with_defaults[:agent_preferences][:search_settings][:tickets].except!(:archive) unless Account.current.archive_tickets_enabled?

        preferences_with_defaults
      end

  end
end