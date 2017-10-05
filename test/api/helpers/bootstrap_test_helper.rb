['portals_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
module BootstrapTestHelper
  include Gamification::GamificationUtil
  include Social::Util
  include PortalsTestHelper

  def index_pattern(agent, account, portal)
    {
      agent: agent_info_pattern(agent),
      account: account_info_pattern(account),
      portal: portal_pattern(portal)
    }
  end

  def agent_info_pattern(agent)
    ret_hash = private_api_agent_pattern({}, agent).merge(
      last_active_at: agent.last_active_at.try(:utc).try(:iso8601),
      abilities: agent.user.abilities,
      assumable_agents: agent.assumable_agents.map(&:id),
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

  def collab_pattern
    {
      client_id: String,
      client_account_id: String,
      init_auth_token: String,
      collab_url: String,
      rts_url: String
    }
  end

  def social_options_hash
    social_hash = Hash.new
    social_hash[:handles_associated] = handles_associated? ? TrueClass : FalseClass
    social_hash[:social_enabled] = social_enabled? ? TrueClass : FalseClass
    social_hash
  end

  def account_info_pattern(account)
    pattern = {
      full_domain: account.full_domain,
      helpdesk_name: account.helpdesk_name,
      name: account.name,
      time_zone: account.time_zone,
      date_format: account.account_additional_settings.date_format,
      language: account.language,
      features: Array,
      launched: Array,
      settings: {
        personalized_email_replies: wildcard_matcher,
        compose_email_enabled: wildcard_matcher,
        include_survey_manually: wildcard_matcher,
        show_on_boarding: account.account_onboarding_pending?
      },
      agents: Array,
      groups: Array,
      verified: account.verified?,
      created_at: account.created_at.try(:utc),
      ssl_enabled: account.ssl_enabled?
    }

    pattern[:collaboration] = collab_pattern if account.collaboration_enabled?
    pattern[:social_options] = social_options_hash if account.features?(:twitter) || account.basic_twitter_enabled?
    if User.current.privilege?(:manage_users) || User.current.privilege?(:manage_account)
      pattern[:subscription] = {
        agent_limit: account.subscription.agent_limit,
        state: account.subscription.state,
        subscription_plan: String,
        trial_days: account.subscription.trial_days
      }
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
end
