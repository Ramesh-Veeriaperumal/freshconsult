['portals_customisation_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
['config_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module BootstrapTestHelper
  include Gamification::GamificationUtil
  include Social::Util
  include PortalsCustomisationTestHelper
  include ConfigTestHelper
  def index_pattern(agent, account, portal)
    {
      agent: agent_info_pattern(agent),
      account: account_info_pattern(account),
      portal: portal_pattern(portal),
      config: config_pattern
    }
  end

  def account_pattern(account, portal)
    {
      account: account_info_pattern_simple(account),
      portal: portal_pattern(portal),
      config: config_pattern
    }
  end

  def agent_info_pattern(agent)
    ret_hash = private_api_agent_pattern({}, agent).merge(
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601),
      abilities: agent.user.abilities,
      assumable_agents: agent.assumable_agents.map(&:id),
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
      freshconnect_enabled: account.freshconnect_enabled? && account.freshid_enabled? && User.current.freshid_authorization
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
      preferences: Account.current.freshchat_account.try(:preferences),
      enabled: Account.current.freshchat_account.try(:enabled),
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
        freshmarketer_linked: account.account_additional_settings.freshmarketer_linked?
      },
      verified: account.verified?,
      created_at: account.created_at.try(:utc),
      ssl_enabled: account.ssl_enabled?
    }

    pattern[:collaboration] = collab_pattern(account) if ( account.collaboration_enabled? || (account.freshconnect_enabled? && account.freshid_enabled? && User.current.freshid_authorization))
    pattern[:social_options] = social_options_hash if account.features?(:twitter) || account.basic_twitter_enabled?
    pattern[:dashboard_limits] = account.account_additional_settings.custom_dashboard_limits if account.custom_dashboard_enabled?
    pattern[:freshchat] = freshchat_hash if account.freshchat_enabled?
    pattern.merge!(sandbox_info(account))
    if User.current.privilege?(:manage_users) || User.current.privilege?(:manage_account)
      pattern[:subscription] = {
        agent_limit: account.subscription.agent_limit,
        state: account.subscription.state,
        subscription_plan: String,
        trial_days: account.subscription.trial_days,
        is_copy_right_enabled: account.copy_right_enabled?
      }
    end
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
      group_ids: agent.group_ids
    }
  end

  def group_simple_pattern(group)
    {
      id: group.id,
      name: group.name,
      agent_ids: group.agents.map(&:id),
      skill_based_round_robin_enabled: group.skill_based_round_robin_enabled?
    }
  end

  def agent_group_pattern(account)
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
end
