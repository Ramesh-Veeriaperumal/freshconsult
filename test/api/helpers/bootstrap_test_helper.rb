['portals_customisation_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['config_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module BootstrapTestHelper
  include Gamification::GamificationUtil
  include Social::Util
  include PortalsCustomisationTestHelper
  include ConfigTestHelper
  include FieldServiceManagementHelper
  include AccountConstants
  include MarketplaceConfig

  DEFAULTS_FONT_SETTINGS = {
    email_template: {
      'font-size' => '14px',
      'font-family' => '-apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Helvetica Neue, Arial, sans-serif'
    }
  }.freeze

  def index_pattern(agent, account, portal, dkim_config_required = false)
    {
      agent: agent_info_pattern(agent),
      account: account_info_pattern(account),
      portal: portal_pattern(portal),
      config: config_pattern(dkim_config_required)
    }
  end

  def account_pattern(account, portal, dkim_config_required = false)
    {
      account: account_info_pattern_simple(account),
      portal: portal_pattern(portal),
      config: config_pattern(dkim_config_required)
    }
  end

  def agent_info_pattern(agent)
    ret_hash = private_api_agent_pattern({}, agent).merge(
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601),
      abilities: agent.user.abilities,
      group_ids: agent.group_ids,
      is_assumed_user: session.has_key?(:assumed_user),
      preferences: agent.preferences
    )
    if gamification_feature?(Account.current)
      ret_hash.merge!(
        points: agent.points,
        scoreboard_level_id: agent.scoreboard_level_id,
        next_level_id: agent.next_level.try(:id)
      )
    end
    ret_hash[:collision_user_hash] = socket_auth_params('agentcollision', agent) if Account.current.features?(:collision)
    ret_hash[:autorefresh_user_hash] = socket_auth_params('autorefresh', agent) if Account.current.auto_refresh_enabled?

    ret_hash
  end

  def collab_pattern(account)
    {
      client_id: String,
      client_account_id: String,
      init_auth_token: String,
      collab_url: String,
      rts_url: String,
      freshconnect_enabled: account.freshconnect_enabled? && account.freshid_integration_enabled? && User.current.freshid_authorization
    }
  end

  def social_options_hash
    social_hash = Hash.new
    social_hash[:handles_associated] = handles_associated? ? TrueClass : FalseClass
    social_hash[:social_enabled] = social_enabled? ? TrueClass : FalseClass
    social_hash
  end

  def freshchat_hash
    {
      widget_host: Freshchat::Account::CONFIG[:visitorWidgetHostUrl],
      preferences: Account.current.freshchat_account.try(:preferences),
      enabled: Account.current.freshchat_account.try(:enabled),
      domain: Account.current.freshchat_account.try(:domain),
      app_id: Account.current.freshchat_account.try(:app_id)
    }
  end

  def account_info_pattern_simple(account)
    pattern = {
      ref_id: account.id,
      full_domain: account.full_domain,
      helpdesk_name: account.helpdesk_name,
      name: account.name,
      time_zone: account.time_zone,
      date_format: account.account_additional_settings.date_format,
      language: account.language,
      portal_languages: JSON.parse(account.all_portal_language_objects.to_json),
      features: Array,
      launched: Array,
      settings: {
        personalized_email_replies: wildcard_matcher,
        compose_email_enabled: wildcard_matcher,
        restricted_compose_email_enabled: wildcard_matcher,
        include_survey_manually: wildcard_matcher,
        show_on_boarding: account.account_onboarding_pending?,
        announcement_bucket: account.account_additional_settings.additional_settings[:announcement_bucket].to_s,
        freshmarketer_linked: account.account_additional_settings.freshmarketer_linked?,
        freshcaller_linked: account.freshcaller_account.present? && account.freshcaller_account.enabled?,
        onboarding_version: account.account_additional_settings.additional_settings[:onboarding_version],
        freshdesk_freshsales_bundle: account.account_additional_settings.additional_settings[:freshdesk_freshsales_bundle] || false,
        bundle_id: account.account_additional_settings.additional_settings.try(:[], :bundle_id),
        bundle_name: account.account_additional_settings.additional_settings.try(:[], :bundle_name)
      },
      verified: account.verified?,
      created_at: account.created_at.try(:utc),
      marketplace_settings: marketplace_settings,
      email_fonts: account.account_additional_settings.email_template_settings,
      ssl_enabled: account.ssl_enabled?
    }

    fetch_fsm_settings if account.field_service_management_enabled?
    pattern[:collaboration] = collab_pattern(account) if ( account.collaboration_enabled? || (account.freshconnect_enabled? && account.freshid_integration_enabled? && User.current.freshid_authorization))
    pattern[:social_options] = social_options_hash if account.features?(:twitter) || account.basic_twitter_enabled?
    pattern[:dashboard_limits] = account.account_additional_settings.custom_dashboard_limits if account.custom_dashboard_enabled?
    pattern[:freshchat] = freshchat_hash if account.freshchat_enabled?
    cancellation_requested = account.account_cancellation_requested?
    pattern[:account_cancellation_requested] =  cancellation_requested
    pattern[:account_cancellation_requested_time] = Time.at(account.account_cancellation_requested_time.to_i / 1000).utc if cancellation_requested && account.launched?(:downgrade_policy)
    pattern[:organisation_domain] = account.organisation_from_cache.try(:alternate_domain) || account.organisation_from_cache.try(:domain)
    pattern[:freshdesk_sso_enabled] = account.freshdesk_sso_enabled?
    pattern.merge!(sandbox_info(account))
    first_invoice = account.subscription.subscription_invoices.first
    pattern[:subscription] = {
      agent_limit: account.subscription.agent_limit,
      state: account.subscription.state,
      subscription_plan: String,
      trial_days: account.subscription.trial_days,
      is_copy_right_enabled: account.copy_right_enabled?,
      signup_date: account.subscription.created_at,
      first_invoice_date: first_invoice.nil? ? nil : first_invoice.created_at
    }
    pattern[:subscription][:mrr] = account.subscription.cmrr if User.current.privilege?(:admin_tasks) || User.current.privilege?(:manage_account)
    pattern[:subscription][:invoice_email] = account.invoice_emails.first if User.current.privilege?(:manage_account)
    pattern[:subscription][:field_agent_limit] = (account.subscription.field_agent_limit || 0) if account.field_service_management_enabled?
    pattern[:contact_info] = account.contact_info.presence || {}
    pattern[:contact_info][:company_name] = account.account_configuration.admin_company_name
    pattern[:anonymous_account] = true if account.anonymous_account?
    pattern
  end

  def account_info_pattern(account)
    account_info_pattern_simple(account).merge(
      {
        agents: Array,
        groups: Array,
      }
    )
  end

  def sandbox_info(account)
    sandbox_info = {}
    sandbox_info[:sandbox] = {}
    sandbox_info[:sandbox][:account_type] = account.account_type if account.sandbox_job || account.sandbox?
    sandbox_info[:sandbox][:production_url] = account.account_additional_settings.additional_settings[:sandbox].try(:[], :production_url) if account.sandbox?
    sandbox_info
  end

  def agent_simple_pattern(agent)
    {
      id: agent.user_id,
      contact: {
        name: agent.user.name,
        email: agent.user.email
      },
      group_ids: agent.group_ids,
      type: AgentType.agent_type_name(agent.agent_type)
    }
  end

  def group_assignment_type(group)
    GroupConstants::DB_ASSIGNMENT_TYPE_FOR_MAP[group.ticket_assign_type]
  end

  def round_robin_enabled?
    Account.current.features? :round_robin
  end

  def round_robin_hash(group)
    rr_type=get_round_robin_type(group)
    hash={
      round_robin_type: rr_type,
      allow_agents_to_change_availability: group.toggle_availability
    }
    hash.merge!({capping_limit: group.capping_limit}) unless rr_type == GroupConstants::ROUND_ROBIN
    hash
  end

  def group_simple_pattern(group)
    ret_hash={
      id: group.id,
      name: group.name,
      agent_ids: group.agents.map(&:id),
      group_type: GroupType.group_type_name(group.group_type),
      assignment_type: group_assignment_type(group)
    }
    if round_robin_enabled? && group_assignment_type(group) == GroupConstants::ROUND_ROBIN_ASSIGNMENT
      ret_hash.merge!(round_robin_hash(group))
    end
    ret_hash
  end

  def agent_group_pattern(account)
    pattern = {'agents' => [], 'groups' => []}
    account.users.where(helpdesk_agent: true).each do |user|
      pattern['agents'] << agent_simple_pattern(user.agent)
    end
    account.groups.each do |group|
      pattern['groups'] << group_simple_pattern(group)
    end
    pattern
  end

  def agent_group_pattern_for_channels(account)
    pattern = {'agents' => [], 'groups' => []}
    account.agents.each do |agent|
      pattern['agents'] << agent_simple_pattern(agent)
    end
    account.groups.each do |group|
      pattern['groups'] << group_simple_pattern(group)
    end
    pattern
  end

  def socket_auth_params(connection, agent)
    aes = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    aes.encrypt
    aes.key = Digest::SHA256.digest(NodeConfig[connection]['key'])
    aes.iv  = NodeConfig[connection]['iv']
    user_obj = get_user_object(agent)
    account_data = {
      account_id: user_obj.account_id,
      user_id: user_obj.id,
      avatar_url: user_obj.avatar_url
    }.to_json
    encoded_data = Base64.encode64(aes.update(account_data) + aes.final)
    encoded_data
  end

  def get_user_object(agent)
    return agent if agent.is_a?(User)
    agent.user
  end

  def account_with_trial_subscription_pattern(account, portal,
                                              subscription, subscription_plan)
    response_pattern = account_pattern(account, portal)
    response_pattern[:account][:trial_subscription] = {
      active: (subscription.status == 0),
      days_left: subscription.days_left,
      days_left_until_next_trial: subscription.days_left_until_next_trial,
      plan_name: subscription_plan.name
    }
    response_pattern
  end

  private

  def get_round_robin_type(group)
    round_robin_type=1 if group.ticket_assign_type==1 && group.capping_limit==0
    round_robin_type=2 if group.ticket_assign_type==1 && group.capping_limit!=0
    round_robin_type=3 if group.ticket_assign_type==2
    round_robin_type
  end

  def marketplace_settings
    {
      data_pipe_key: DATA_PIPE_KEY,
      awol_region: AWOL_REGION
    }
  end

end