class AccountDecorator < ApiDecorator
  include Social::Util
  def to_hash
    simple_hash.merge(agents_groups_hash)
  end

  def simple_hash
    ret_hash = {
      ref_id: record.id,
      full_domain: record.full_domain,
      helpdesk_name: record.helpdesk_name,
      name: record.name,
      time_zone: record.time_zone,
      date_format: record.account_additional_settings.date_format,
      language: record.language,
      features: record.enabled_features_list,
      launched: record.all_launched_features,
      subscription: subscription_hash,
      portal_languages: record.all_portal_language_objects,
      settings: settings_hash,
      ssl_enabled: record.ssl_enabled?,
      verified: record.verified?,
      created_at: record.created_at.try(:utc)
    }
    ret_hash.merge!(sandbox_info)
    ret_hash[:collaboration] = collaboration_hash if record.collaboration_enabled? || (record.freshconnect_enabled? && record.freshid_enabled? && User.current.freshid_authorization)
    ret_hash[:social_options] = social_options_hash if record.features?(:twitter) || record.basic_twitter_enabled?
    ret_hash[:dashboard_limits] = record.account_additional_settings.custom_dashboard_limits if record.custom_dashboard_enabled?
    ret_hash[:freshchat] = freshchat_options_hash if record.freshchat_enabled?
    trial_subscription = record.latest_trial_subscription_from_cache
    ret_hash[:trial_subscription] = trial_subscription_hash(trial_subscription) if trial_subscription
    ret_hash[:account_cancellation_requested] = record.account_cancellation_requested?
    ret_hash
  end

  def agents_groups_hash
    {
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
      ((record.features.map(&:to_sym) - Account::BITMAP_FEATURES) + record.features_list).uniq
      # Negating Bitmap features from the DB features,
      # so as to not cause false positives when DB write is turned OFF for that feature.
    end

    def subscription_hash
      subscription = record.subscription
      first_invoice = subscription.subscription_invoices.first
      ret_hash = {
        agent_limit: subscription.agent_limit,
        state: subscription.state,
        subscription_plan: subscription.subscription_plan.name,
        trial_days: subscription.trial_days,
        is_copy_right_enabled: record.copy_right_enabled?,
        signup_date: subscription.created_at,
        first_invoice_date: first_invoice.nil? ? nil : first_invoice.created_at
      }
      ret_hash[:mrr] = subscription.cmrr if User.current.privilege?(:admin_tasks) || User.current.privilege?(:manage_account)
      ret_hash
    end

    def settings_hash
      acct_additional_settings = record.account_additional_settings
      {
        personalized_email_replies: record.features.personalized_email_replies?,
        compose_email_enabled: record.compose_email_enabled?,
        restricted_compose_email_enabled: record.restricted_compose_enabled?,
        include_survey_manually: include_survey_manually?,
        show_on_boarding: record.account_onboarding_pending?,
        announcement_bucket: acct_additional_settings.additional_settings[:announcement_bucket].to_s,
        freshmarketer_linked: acct_additional_settings.freshmarketer_linked?
      }
    end

    def social_options_hash
      {
        handles_associated: handles_associated?,
        social_enabled: social_enabled?
      }
    end

    def freshchat_options_hash
      {
        preferences: record.freshchat_account.try(:preferences),
        enabled: record.freshchat_account.try(:enabled),
        app_id: record.freshchat_account.try(:app_id)
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

    def sandbox_info
      sandbox_info = {}
      sandbox_info[:sandbox] = {}
      sandbox_info[:sandbox][:account_type] = record.account_type if record.sandbox_job || record.sandbox?
      sandbox_info[:sandbox][:production_url] = record.account_additional_settings.additional_settings[:sandbox].try(:[], :production_url) if record.sandbox?
      sandbox_info
    end

    def trial_subscription_hash(trial_subscription)
      {
        active: trial_subscription.active?,
        days_left: trial_subscription.days_left,
        days_left_until_next_trial: trial_subscription.days_left_until_next_trial,
        plan_name: trial_subscription.trial_plan
      }
    end
end
