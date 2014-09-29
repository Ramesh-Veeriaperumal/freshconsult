module SecurityNotification

  private

    def notify_admins(model, subject, message_body_file, model_changes)
      SecurityEmailNotification.send_later(:deliver_admin_alert_mail,
          model, subject, message_body_file, model_changes)
    end

end
