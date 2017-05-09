class AccountDecorator < ApiDecorator
  def to_hash
    {
      full_domain: record.full_domain,
      helpdesk_name: record.helpdesk_name,
      name: record.name,
      time_zone: record.time_zone,
      date_format: date_format,
      features: features_list,
      launched: launch_party_features,
      subscription: subscription_hash,
      settings: settings_hash,
      agents: agents_hash,
      groups: groups_hash
    }
  end

  private

    def date_format
      date_format = Account::DATEFORMATS[record.account_additional_settings.date_format]
      Account::DATA_DATEFORMATS[date_format]
    end

    def features_list
      (record.features.map(&:to_sym) + record.features_list).uniq
    end

    def launch_party_features
      LaunchParty.new.launched_for(record)
    end

    def subscription_hash
      subscription = record.subscription
      {
        agent_limit: subscription.agent_limit,
        state: subscription.state,
        subscription_plan: subscription.subscription_plan.name
      }
    end

    def settings_hash
      {
        personalized_email_replies: record.features.personalized_email_replies?,
        compose_email_enabled: record.compose_email_enabled?,
        include_survey_manually: include_survey_manually?
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
end
