module Utils
  module RequesterPrivilege
    def has_requester_privilege?
      unless has_requester_feature?
        return has_other_notifications_privilege?
      end
      privilege?(:manage_requester_notifications)
    end

    def has_requester_feature?
      Account.current.launched?('requester_privilege')
    end

    def has_other_notifications_privilege?
      privilege?(:manage_email_settings)
    end
  end
end
