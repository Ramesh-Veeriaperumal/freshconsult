module Agents
  module Preferences   
  
    def preferences
      self.user.preferences[:agent_preferences]
    end

    # Helpers for getting and settings user based keyboard shortcuts enable/disable
    def shortcuts_enabled?
      preferences[:shortcuts_enabled]
    end

    def shortcuts_enabled=(enabled)
      update_preferences({:shortcuts_enabled => enabled})
    end

    # Helpers for getting and settings user based keyboard shortcuts key mapping
    def shortcuts_mapping
      preferences[:shortcuts_mapping]
    end

    def shortcuts_mapping=(mapping)
      update_preferences({:shortcuts_mapping => mapping})
    end

    # Helpers for getting and settings user based notification timestamp
    def notification_timestamp
      preferences[:notification_timestamp]
    end

    def notification_timestamp=(timestamp)
      update_preferences({:notification_timestamp => timestamp})
    end

    def onboarding_completed?
      preferences[:show_onBoarding]
    end

    def onboarding_completed=(enabled)
      update_preferences({:show_onBoarding => enabled})
    end

    # Helpers for getting and setting Freshchat token
    def freshchat_token
      preferences[:freshchat_token]
    end

    def freshchat_token=(token)
      update_preferences(freshchat_token: token)
    end

    # Helpers for getting and setting Search Settings
    def search_settings
      preferences[:search_settings]
    end

    def search_settings=(search_settings)
      update_preferences(search_settings: search_settings.deep_symbolize_keys)
    end

    private

      def update_preferences(settings = {})
        self.user.merge_preferences = { :agent_preferences => settings }
      end
  end
end
