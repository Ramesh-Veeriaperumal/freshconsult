class AccountDecorator < ApiDecorator
  include Social::Util
  def to_hash
    ret_hash = {
      full_domain: record.full_domain,
      helpdesk_name: record.helpdesk_name,
      name: record.name,
      time_zone: record.time_zone,
      date_format: record.account_additional_settings.date_format,
      language: record.language,
      features: record.enabled_features_list,
      launched: launch_party_features,
      subscription: subscription_hash,
      settings: settings_hash,
      ssl_enabled: record.ssl_enabled?,
      agents: agents_hash,
      groups: groups_hash,
      verified: record.verified?,
      created_at: record.created_at.try(:utc)
    }
    ret_hash[:collaboration] = collaboration_hash if record.collaboration_enabled?
    ret_hash[:social_options] = social_options_hash if record.features?(:twitter) || record.basic_twitter_enabled?
    ret_hash
  end

  private

    def launch_party_features
      LaunchParty.new.launched_for(record)
    end

    def subscription_hash
      subscription = record.subscription
      {
        agent_limit: subscription.agent_limit,
        state: subscription.state,
        subscription_plan: subscription.subscription_plan.name,
        trial_days: subscription.trial_days
      }
    end

    def settings_hash
      {
        personalized_email_replies: record.features.personalized_email_replies?,
        compose_email_enabled: record.compose_email_enabled?,
        include_survey_manually: include_survey_manually?
      }
    end

    def social_options_hash
      {
        handles_associated: handles_associated?,
        social_enabled: social_enabled?
      }
    end

    def agents_hash
      agents = record.agents_details_from_cache
      agents.map do |agent|
        AgentDecorator.new(agent, group_mapping_ids: agent_groups[:agents][agent.id] || []).to_restricted_hash
      end
    end

    def groups_hash
      groups = record.groups_from_cache
      groups.map do |group|
        GroupDecorator.new(group, agent_mapping_ids: agent_groups[:groups][group.id] || []).to_restricted_hash
      end
    end

    def agent_groups
      @agent_group_mapping ||= begin
        record.agent_groups_from_cache.inject(agents: {}, groups: {}) do |mapping, ag|
          (mapping[:agents][ag.user_id] ||= []).push(ag.group_id)
          (mapping[:groups][ag.group_id] ||= []).push(ag.user_id)
          mapping
        end
      end
    end

    def include_survey_manually?
      record.new_survey_enabled? && record.active_custom_survey_from_cache.try(:send_while) == Survey::SPECIFIC_EMAIL_RESPONSE
    end

    def collaboration_hash
      Collaboration::Payloads.new.account_payload
    end
end
