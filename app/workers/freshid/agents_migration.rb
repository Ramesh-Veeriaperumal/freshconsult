module Freshid
  class AgentsMigration < BaseWorker
    include Freshid::SnsErrorNotificationExtensions

    sidekiq_options :queue => :freshid_agents_migration, :retry => 0, :backtrace => true, :failures => :exhausted
    AGENTS_MIGRATION_WORKER_ERROR = "AGENTS_MIGRATION_WORKER_ERROR"
    FRESHID_MIGRATE_AGENTS_ERROR = "FRESHID_MIGRATE_AGENTS_ERROR"
    FRESHID_REVERT_AGENTS_ERROR = "FRESHID_REVERT_AGENTS_ERROR"
    FRESHID_USER_CREATION_ERROR = "FRESHID_USER_CREATION_ERROR"
    FRESHID_AGENT_PASSWORD_POLICY_ERROR = "FRESHID_AGENT_PASSWORD_POLICY_ERROR"
    FRESHID_PWD_RESET_EMAIL_NOTIF_ERROR = "FRESHID_PWD_RESET_EMAIL_NOTIF_ERROR"
    FRESHID_AGENT_INVITE_EMAIL_NOTIF_ERROR = "FRESHID_AGENT_INVITE_EMAIL_NOTIF_ERROR"

    def perform(args={})
      args.symbolize_keys!
      @revert_migration = args[:revert_migration] || false
      @account = ::Account.current
      fid_migration_in_progress = @account.freshid_migration_in_progress?

      Rails.logger.info "Inside Freshid::AgentsMigration worker :: revert_migration=#{@revert_migration}, a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}, fid_migration_in_progress=#{fid_migration_in_progress}"

      return if fid_migration_in_progress

      @account.initiate_freshid_migration
      @revert_migration ? revert_freshid : migrate_agents

    rescue Exception => e
      log_migration_error(AGENTS_MIGRATION_WORKER_ERROR, { revert_migration: @revert_migration }, e)
      # @revert_migration ? migrate_agents : revert_freshid
    ensure
      @account.freshid_migration_complete
    end

    private
      def migrate_agents
        Rails.logger.info "FRESHID Enabling and Migrating Agents :: a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}"
        account_admin = @account.all_technicians.find_by_email(@account.admin_email) || @account.account_managers.first
        @account.launch_freshid_with_omnibar
        perform_migration_changes
        @account.create_freshid_org_and_account(nil, nil, account_admin)
        @account.all_technicians.where("id != #{account_admin.id}").find_each { |user| migrate_user_to_freshid(user) if user.freshid_authorization.blank? }
      rescue Exception => e
        log_migration_error(FRESHID_MIGRATE_AGENTS_ERROR, {}, e)
      end

      def revert_freshid
        Rails.logger.info "FRESHID Disabling and Removing Agents :: a=#{@account.try(:id)}, d=#{@account.try(:full_domain)}"
        perform_migration_changes
        freshid_account_params = {
          name: @account.name,
          account_id: @account.id,
          domain: @account.full_domain
        }
        Freshid::Account.new(freshid_account_params).destroy
        @account.authorizations.where(provider: Freshid::Constants::FRESHID_PROVIDER).destroy_all
      rescue Exception => e
        log_migration_error(FRESHID_REVERT_AGENTS_ERROR, {}, e)
      ensure
        @account.rollback(:freshid)
      end

      def perform_migration_changes
        modify_agent_password_policy
        modify_password_reset_email_notification
        modify_agent_invitation_email_notification
      end

      def modify_agent_password_policy
        @revert_migration ? @account.agent_password_policy.try(:destroy) : @account.build_default_password_policy(PasswordPolicy::USER_TYPE[:agent]).save!
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

      def migrate_user_to_freshid user
        user.create_freshid_user!
      rescue Exception => e
        log_migration_error(FRESHID_USER_CREATION_ERROR, { u: user.id, email: user.email }, e)
      end

      def log_migration_error message, args, exception
        args.merge!({a: @account.try(:id), d: @account.try(:full_domain)})
        error_message = "#{message} :: "
        args.each { |key, value| error_message += "#{key}=#{value}, "}
        error_message += "e=#{exception.inspect}, backtrace=#{exception.backtrace}"

        Rails.logger.error error_message
        notify_error(message, args, exception)
      end
  end
end