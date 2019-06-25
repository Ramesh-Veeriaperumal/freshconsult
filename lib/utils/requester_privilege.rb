module Utils
  module RequesterPrivilege
    REQUESTER_KEYS = ['requester_notification', 'requester_subject_template', 'requester_template'].freeze
    REQUESTER_TEMPLATE = 'requester_template'.freeze

    def accessing_requester_info?
      return false unless @email_notification.try(:visible_to_requester?)

      if params[:email_notification]
        (params[:email_notification].keys & REQUESTER_KEYS).present?
      elsif params[:type]
        params[:type] == REQUESTER_TEMPLATE
      end
    end

    def has_requester_privilege?
      unless has_requester_feature?
        return has_other_notifications_privilege?
      end
      privilege?(:manage_requester_notifications)
    end

    def has_requester_feature?
      Account.current.launched?('requester_privilege')
    end

    def has_all_privileges?
      has_requester_privilege? && has_other_notifications_privilege?
    end

    def has_other_notifications_privilege?
      privilege?(:manage_email_settings)
    end

    def check_other_notification_privilege
      has_other_notifications_privilege? && !accessing_requester_info?
    end
  end
end
