module Freshid::MigrationUtil
  include Freshid::SnsErrorNotificationExtensions
  AGENTS_MIGRATION_WORKER_ERROR = 'AGENTS_MIGRATION_WORKER_ERROR'.freeze
  FRESHID_MIGRATE_AGENTS_ERROR = 'FRESHID_MIGRATE_AGENTS_ERROR'.freeze
  FRESHID_REVERT_AGENTS_ERROR = 'FRESHID_REVERT_AGENTS_ERROR'.freeze
  FRESHID_USER_CREATION_ERROR = 'FRESHID_USER_CREATION_ERROR'.freeze
  FRESHID_AGENT_PASSWORD_POLICY_ERROR = 'FRESHID_AGENT_PASSWORD_POLICY_ERROR'.freeze
  FRESHID_PWD_RESET_EMAIL_NOTIF_ERROR = 'FRESHID_PWD_RESET_EMAIL_NOTIF_ERROR'.freeze
  FRESHID_AGENT_INVITE_EMAIL_NOTIF_ERROR = 'FRESHID_AGENT_INVITE_EMAIL_NOTIF_ERROR'.freeze

  def perform_migration_changes
    modify_agent_password_policy
    modify_password_reset_email_notification
    modify_agent_invitation_email_notification
  end

  def modify_agent_password_policy
    @revert_migration ? @account.build_default_password_policy(PasswordPolicy::USER_TYPE[:agent]).save! : @account.agent_password_policy.try(:destroy)
  rescue Exception => e
    log_migration_error(FRESHID_AGENT_PASSWORD_POLICY_ERROR, { revert_migration: @revert_migration }, e)
  end

  def modify_password_reset_email_notification
    password_reset_email_notification = @account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET)
    password_reset_email_notification.toggle_agent_notification(@revert_migration) if password_reset_email_notification.present?
  rescue Exception => e
    log_migration_error(FRESHID_PWD_RESET_EMAIL_NOTIF_ERROR, { revert_migration: @revert_migration }, e)
  end

  def modify_agent_invitation_email_notification
    agent_invitation_email_notification = @account.email_notifications.find_by_notification_type(EmailNotification::AGENT_INVITATION)
    return if @revert_migration != agent_invitation_email_notification.present? # Return if email_notif not present to delete(rever migration) or email_notif already present(migration)
    if @revert_migration
      agent_invitation_email_notification.destroy
    else
      @account.email_notifications.create(
        notification_type: EmailNotification::AGENT_INVITATION,
        requester_notification: false,
        agent_notification: true,
        agent_template: EmailNotificationConstants::AGENT_INVITE_NOTIFICATION[:agent_template],
        agent_subject_template: EmailNotificationConstants::AGENT_INVITE_NOTIFICATION[:agent_subject_template]
      )
    end
  rescue Exception => e
    log_migration_error(FRESHID_AGENT_INVITE_EMAIL_NOTIF_ERROR, { revert_migration: @revert_migration }, e)
  end

  def migrate_user_to_freshid(user)
    user.create_freshid_user!
  rescue Exception => e
    log_migration_error(FRESHID_USER_CREATION_ERROR, { u: user.id, email: user.email }, e)
  end

  def log_migration_error(message, args, exception)
    args[:a] = @account.try(:id)
    args[:d] = @account.try(:full_domain)
    error_message = "#{message} :: "
    args.each { |key, value| error_message += "#{key}=#{value}, " }
    error_message += "e=#{exception.inspect}, backtrace=#{exception.backtrace}"

    Rails.logger.error error_message
    notify_error(message, args, exception)
  end
end
