module Freshid::Fdadmin::MigrationHelper
  FDADMIN_FRESHID_MIGRATION_WORKER_ERROR = 'FDADMIN_FRESHID_MIGRATION_WORKER_ERROR'.freeze
  FDADMIN_FRESHID_REVERT_AGENTS_ERROR = 'FDADMIN_FRESHID_REVERT_AGENTS_ERROR'.freeze
  FDADMIN_FRESHID_SILENT_MIGRATION_ERROR = 'FDADMIN_FRESHID_SILENT_MIGRATION_ERROR'.freeze
  FDADMIN_FRESHID_V2_MIGRATION_ERROR = 'FDADMIN_FRESHID_V2_MIGRATION_ERROR'.freeze
  DISABLE_V2_MIGRATION_INPROGRESS = :disable_org_v2_inProgress
  ENABLE_V1_MIGRATION_INPROGRESS = :enable_freshid_v1_inProgress
  ENABLE_V2_MIGRATION_INPROGRESS = :enable_org_v2_inProgress

  FRESHID_V1_EMAIL_SUBJECT = 'Migrate accounts to freshid V1'.freeze
  FRESHID_VALIDATION_EMAIL_SUBJECT = 'Freshid Validation report'.freeze
  FRESHID_V2_EMAIL_SUBJECT = 'Migrate accounts From Freshid V1 to V2'.freeze

  CUSTSERV_EMAIL = 'custserv@freshdesk.com'.freeze
  PASSWORD_TYPE = 'sha512'.freeze
  AGENT_INVITATION_EMAIL_TEMPLATE = 'Hi {{agent.name}},<br /><br />Your {{helpdesk_name}} account has been created.<br /><br />Click <a href="{{helpdesk_url}}">here</a> to go to your account. <br /><br />If the above URL does not work, try copying and pasting it into your browser. Please feel free to contact us, if you continue to face any problems.<br /><br />Regards,<br />{{helpdesk_name}}'.freeze

  class Emailer < ActionMailer::Base
    def export_logs(file_list, subject, message, to_email)
      file_list.each do |a_file|
        attachments[a_file] = {
          mime_type: 'text/csv',
          content: File.read("#{Rails.root}/tmp/#{a_file}", mode: 'rb')
        }
      end
      mail(from: CUSTSERV_EMAIL, to: to_email, subject: subject) do |part|
        part.html { message.to_s }
      end.deliver
    end
  end

  def write_file(file_name, data)
    file_path = File.join("#{Rails.root}/tmp", file_name)
    # file_path = Rails.root.join('tmp', file_name)
    File.open(file_path, 'w') { |f| f.write(data) }
  end

  def delete_file(file_name)
    file_path = File.join("#{Rails.root}/tmp", file_name)
    File.delete(file_path)
  end

  # Set redis key to avoid Password policy, SSO and Portal customization migration
  def sso_enabled(account)
    redis_key_exists?(FRESHID_MIGRTATION_SSO_ALLOWED) && account.sso_enabled?
  end

  def portal_customization?(account)
    has_portal_customization = account.portal_pages.any? { |portal_page| portal_page.token == :user_login }
    redis_key_exists?(FRESHID_MIGRTATION_PORTAL_CUSTOMIZATION_ALLOWED) && has_portal_customization
  end

  def password_policy_modified(account)
    @default_password_policy_config = { 'minimum_characters' => '8', 'session_expiry' => '90', 'password_expiry' => '36500', 'cannot_be_same_as_past_passwords' => '3' }

    agent_password_policy = account.agent_password_policy.try(:configs) || @default_password_policy_config
    contact_password_policy = account.contact_password_policy.try(:configs) || @default_password_policy_config
    password_policy_modified = (agent_password_policy != @default_password_policy_config) || (contact_password_policy != @default_password_policy_config)

    redis_key_exists?(FRESHID_MIGRTATION_PASSWORD_POLICY_ALLOWED) && password_policy_modified
  end

  def migration_check_fails?(account)
    Rails.logger.info "MIGRATION_CHECK :: a=#{account.id} :: Subscription_nil=#{account.subscription.nil?}, Suspended=#{account.subscription.suspended?}, Freshid_integration=#{account.freshid_integration_enabled?}, SSO_enabled=#{sso_enabled(account)}, Portal_customization=#{portal_customization?(account)}, Password_policy=#{password_policy_modified(account)}"
    account.subscription.nil? || account.subscription.suspended? || account.freshid_integration_enabled? || sso_enabled(account) || portal_customization?(account) || password_policy_modified(account)
  end

  def migration_check_pass?(account)
    !migration_check_fails?(account)
  end

  def check_and_enable_freshid(account)
    return true if account.freshid_enabled?
    uid = account.authorizations.where(provider: 'freshid').first.uid
    if agent_mapped_correctly?(account) && validate_v1_uuid_format(uid)
      account.launch(:freshid)
      return true
    end
    false
  end

  def check_and_enable_freshid_v2(account)
    return true if account.freshid_org_v2_enabled?
    uid = account.authorizations.where(provider: 'freshid').first.uid
    if agent_mapped_correctly?(account) && !validate_v1_uuid_format(uid)
      account.launch(:freshid_org_v2)
      return true
    end
    false
  end

  def agent_mapped_correctly?(account)
    fd_agent_count = account.all_technicians.count - 1 # -1 for custserv@freshdesk.com
    freshid_agent_count = account.authorizations.where(provider: 'freshid').count
    # if Authorization entry is <= to FD agent count then all agent authorization is present so we can enable freshid
    return true if fd_agent_count <= freshid_agent_count
    Rails.logger.debug "MIGRATION_CHECK :: agent_mapped_correctly? a=#{account.id}, Some agent authorization missing"
    false
  end

  def validate_v1_uuid_format(uuid)
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.match(uuid.to_s.downcase)
  end

  def get_sandbox_account_id(account)
    account.sandbox_job.try(:sandbox_account_id)
  end
end
