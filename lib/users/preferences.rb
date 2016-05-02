module Users
  module Preferences
    # Default settings for user preferences
    DEFAULTS_PREFERENCES = { 
      :agent_preferences => { 
        :shortcuts_enabled => true,
        :shortcuts_mapping => [],
        :notification_timestamp => nil,
        :show_onBoarding => true
        # Add new pref for agents here
      }, 
      :user_preferences => {
        # Add new pref for users here
      }

    }

    def merge_preferences=(pref = {})
      self.preferences = (self.preferences_without_defaults || {}).deep_merge(pref)
    end

    private

      def preferences_with_defaults
        DEFAULTS_PREFERENCES.deep_merge(self.preferences_without_defaults || {}) 
      end

  end
end