class Freshid::Fdadmin::FreshdeskToFreshidMigration < ActiveRecord::Migration
  include Rails.application.routes.url_helpers
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Freshid::Fdadmin::MigrationHelper

  def initialize
    @api_key = FreshIDConfig['v1_migration_api_key']
    @migration_url = FreshIDConfig['v1_migration_url']
    @product = FreshIDConfig['v1_migration_product']
    @account = ::Account.current
    @request_header = { 'x-api-key' => @api_key, 'Content-Type' => 'application/json' }
    @migrated_list = []
    @migrated_list << %w[AccountID AccountDomain UUID AgentID AgentEmail MigratedAt]
    @freshid_logs = []
    @freshid_logs << ['AccountID', 'AccountDomain', 'AgentID', 'Agent Email', 'Status', 'Message', 'Error']
  end

  def freshid_v1_silent_migration(doer_email)
    Rails.logger.info "Freshdesk To Freshid Silent MIGRATION: started a:#{@account.id}"
    begin
      freshid_agent_migration if migration_check_pass?(@account)
    rescue StandardError => e
      Rails.logger.debug "FD_To_Freshid_Silent_MIGRATION_ERROR -- a=#{@account.id} :: exception_from=Account :: exception=#{e.backtrace.join('\n')}"
    ensure
      subject = "#{FRESHID_V1_EMAIL_SUBJECT} A = #{@account.id}"
      message = 'Freshid Migration Logs attached'
      write_file('freshid_error_logs.csv', @freshid_logs.map(&:to_csv).join)
      write_file('migrated_agents.csv', @migrated_list.map(&:to_csv).join)
      file_list = ['freshid_error_logs.csv', 'migrated_agents.csv']
      Emailer.export_logs(file_list, subject, message, doer_email)
      delete_file('freshid_error_logs.csv')
      delete_file('migrated_agents.csv')
    end
  end

  def freshid_agent_migration
    account_created = false
    @account.all_technicians.find_each do |agent|
      begin
        next if agent.authorizations.find_by_provider('freshid') || agent.email.blank? || agent.email == CUSTSERV_EMAIL
        request_body = build_payload(agent, @account)
        response_hash = get_response(request_body)
        response = response_hash[:body]
        error = response_hash[:error]
        account_created = true if response['message']['accounts_created'].present?
        if error.present? || response.try(:[], 'status') != 'SUCCESS'
          @freshid_logs << [@account.id, @account.full_domain, agent.id, agent.email, response.try(:[], 'status'), response.try(:[], 'message').inspect, response.try(:[], 'error').inspect]
          next
        else
          response['message']['uuid'].present? ? agent.create_freshid_authorization(uid: response['message']['uuid']) : raise('FreshID UUID not present')
          @migrated_list << [@account.id, @account.full_domain, response['message']['uuid'], agent.id, agent.email, Time.now.utc]
        end
      rescue StandardError => e
        Rails.logger.error "FRESHID_AGENT_MIGRATION_ERROR -- a=#{@account.id} :: d=#{@account.full_domain} :: exception_from = Agent :: agent_id=#{agent.id} :: agent_email=#{agent.email} :: exception=#{e.backtrace.join('\n')}"
      end
    end
    post_agent_migration
  end

  def post_agent_migration
    Rails.logger.debug "FRESHID_POST_AGENT_MIGRATION started a:#{@account.id}"
    if check_and_enable_freshid(@account)
      # @account.launch(:freshid)
      @account.launch(:freshworks_omnibar)
      @account.agent_password_policy.try(:destroy)
      # Turn off password reset email notification
      @account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET).update_attribute(:agent_notification, false) if @account.email_notifications.find_by_notification_type(EmailNotification::PASSWORD_RESET).present?
      # Create agent invitation email notification
      @account.email_notifications.create(notification_type: EmailNotification::AGENT_INVITATION, requester_notification: false, agent_notification: true, agent_template: AGENT_INVITATION_EMAIL_TEMPLATE, agent_subject_template: '{{portal_name}} agent invitation') unless @account.email_notifications.find_by_notification_type(EmailNotification::AGENT_INVITATION)
    else
      @account.rollback(:freshid)
      Rails.logger.debug "FRESHID_POST_AGENT_MIGRATION_ERROR -- a=#{@account.id} :: d=#{@account.full_domain} :: exception_from=Account :: ACCOUNT_CREATION_ERROR -- freshid_launched=#{@account.launched?(:freshid)}"
    end
    Rails.logger.debug "FRESHID_POST_AGENT_MIGRATION finished a:#{@account.id}"
  rescue StandardError => e
    Rails.logger.error "FRESHID_POST_AGENT_MIGRATION_ERROR -- a=#{@account.id} :: d=#{@account.full_domain} :: exception_from=Account :: message = #{e.message} exception=#{e.backtrace.join('\n')}"
  end

  def build_payload(agent, account)
    hash = {}
    hash['product'] = @product
    #    ---- Agent details ----
    hash['payload'] = {}
    agent_name = agent.name.split(' ', 2)
    hash['payload']['first_name'] = agent_name[0]
    hash['payload']['last_name'] = agent_name[1]
    hash['payload']['phone'] = agent.phone
    hash['payload']['mobile'] = agent.mobile
    hash['payload']['job_title'] = agent.job_title
    hash['payload']['email'] = agent.email
    hash['payload']['redirect_uri'] = support_login_url(host: account.host, protocol: account.url_protocol)
    hash['payload']['password_type'] = PASSWORD_TYPE
    #    ---- Account details ----
    hash['payload']['accounts'] = []
    hash['payload']['accounts'][0] = {}
    hash['payload']['accounts'][0]['account_id'] = account.id
    hash['payload']['accounts'][0]['account_name'] = account.name
    hash['payload']['accounts'][0]['account_domain'] = account.full_domain
    hash['payload']['accounts'][0]['status'] = agent.active ? 'ACTIVATED' : 'DEACTIVATED'
    hash['payload']['accounts'][0]['crypted_password'] = agent.crypted_password
    hash['payload']['accounts'][0]['salt'] = agent.password_salt
    hash['payload']['accounts'][0]['other_logins'] = {}
    hash['payload']['accounts'][0]['other_logins']['google'] = true if agent.authorizations.find_by_provider('google')
    hash['payload']['accounts'][0]['other_logins']['facebook'] = true if agent.authorizations.find_by_provider('facebook')
    hash
  end

  def get_response(body)
    response_hash = { body: '', error: '' }
    begin
      response = RestClient::Request.execute(
        method: :post,
        url: @migration_url,
        headers: @request_header,
        payload: body.to_json
      )
      response_hash[:body] = JSON.parse(response)
    rescue StandardError => e
      response_hash[:body] = JSON.parse(e.response)
      response_hash[:error] = e.message
    end
    response_hash
  end
end
