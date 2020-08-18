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

    # Helpers for getting and settings user based focus mode
    def focus_mode?
      preferences[:focus_mode]
    end
    alias focus_mode focus_mode?

    def focus_mode=(enabled)
      update_preferences(focus_mode: enabled)
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

    def show_loyalty_upgrade
      preferences[:show_loyalty_upgrade]
    end

    def show_loyalty_upgrade=(enabled)
      update_preferences(show_loyalty_upgrade: enabled)
    end

    def show_monthly_to_annual_notification
      preferences[:show_monthly_to_annual_notification]
    end

    def show_monthly_to_annual_notification=(enabled)
      update_preferences(show_monthly_to_annual_notification: enabled)
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

    # Helpers for getting and setting falcon_ui
    def falcon_ui
      preferences[:falcon_ui]
    end

    def falcon_ui=(falcon_ui)
      update_preferences(falcon_ui: falcon_ui)
    end

    # Helpers for getting and setting undo_send
    def undo_send
      preferences[:undo_send]
    end

    def undo_send=(undo_send)
      update_preferences(undo_send: undo_send)
    end

    # Helpers for getting and setting show_onBoarding
    def show_onBoarding # rubocop:disable Naming/MethodName
      preferences[:show_onBoarding]
    end

    def show_onBoarding=(show_onboarding) # rubocop:disable Naming/MethodName
      update_preferences(show_onBoarding: show_onboarding)
    end

    # Helpers for getting and setting Field Service related preferences
    def field_service
      preferences[:field_service]
    end

    def field_service=(field_service)
      update_preferences(field_service: field_service.deep_symbolize_keys)
    end

    private

      def update_preferences(settings = {})
        self.user.merge_preferences = { :agent_preferences => settings }
      end
  end
end
