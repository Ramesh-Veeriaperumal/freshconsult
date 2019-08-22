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
      launched: launched_features_list,
      subscription: subscription_hash,
      portal_languages: record.all_portal_language_objects,
      settings: settings_hash,
      ssl_enabled: record.ssl_enabled?,
      verified: record.verified?,
      email_fonts: record.account_additional_settings.email_template_settings,
      created_at: record.created_at.try(:utc)
    }
    ret_hash.merge!(sandbox_info)
    ret_hash[:collaboration] = collaboration_hash if record.collaboration_enabled? || (record.freshconnect_enabled? && record.freshid_integration_enabled? && User.current.freshid_authorization)
    ret_hash[:social_options] = social_options_hash if record.features?(:twitter) || record.basic_twitter_enabled?
    ret_hash[:dashboard_limits] = record.account_additional_settings.custom_dashboard_limits if record.custom_dashboard_enabled?
    ret_hash[:freshchat] = freshchat_options_hash if record.freshchat_enabled?
    ret_hash[:contact_info] = record.contact_info.presence
    trial_subscription = record.latest_trial_subscription_from_cache
    ret_hash[:trial_subscription] = trial_subscription_hash(trial_subscription) if trial_subscription
    ret_hash[:account_cancellation_requested] = record.account_cancellation_requested?
    ret_hash[:account_cancellation_requested_time] = record.account_cancellation_requested_time.to_i if record.launched?(:downgrade_policy)
    ret_hash[:anonymous_account] = true if record.anonymous_account?
    ret_hash[:organisation_domain] = organisation_domain
    ret_hash[:freshdesk_sso_enabled] = record.freshdesk_sso_enabled?
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
      ret_hash[:invoice_email] = record.invoice_emails.first if account_admin?
      ret_hash[:field_agent_limit] = (subscription.field_agent_limit || 0) if Account.current.field_service_management_enabled?
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
        freshmarketer_linked: acct_additional_settings.freshmarketer_linked?,
        freshcaller_linked: record.freshcaller_account.present?
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
        widget_host: Freshchat::Account::CONFIG[:visitorWidgetHostUrl],
        preferences: record.freshchat_account.try(:preferences),
        enabled: record.freshchat_account.try(:enabled),
        app_id: record.freshchat_account.try(:app_id)
      }
    end

    def agent_types
      @agent_types ||= begin
        record.agent_types_from_cache.each_with_object({}) do |agent_type, mapping|
          mapping[agent_type.agent_type_id] = agent_type.name
        end
      end
    end

    def group_types
      @group_types ||= begin
        record.group_types_from_cache.each_with_object({}) do |group_type, mapping|
          mapping[group_type.group_type_id] = group_type.name
        end
      end
    end

    def agents_hash
      field_service_mgmt_enabled = record.field_service_management_enabled?
      record.account_agent_details_from_cache.map do |agent|
        type_name =  field_service_mgmt_enabled ? agent_types[agent[AgentConstants::AGENTS_USERS_DETAILS[:agent_type]]] : :support_agent
        data = { id: agent[AgentConstants::AGENTS_USERS_DETAILS[:user_id]] }
        data[:contact] = {
          name: agent[AgentConstants::AGENTS_USERS_DETAILS[:user_name]],
          email: agent[AgentConstants::AGENTS_USERS_DETAILS[:user_email]]
        }
        data[:group_ids] = agent_groups[:agents][agent[AgentConstants::AGENTS_USERS_DETAILS[:user_id]]] || []
        data.merge!(type: type_name)
      end
    end

    def groups_hash
      groups = record.groups_from_cache
      group_type_map = Account.current.group_type_mapping
      groups.map do |group|
        GroupDecorator.new(group, agent_mapping_ids: agent_groups[:groups][group.id] || [],
                                  group_type_mapping: group_type_map).to_restricted_hash
      end
    end

    def agent_groups
      @agent_groups ||= record.agent_groups_ids_only_from_cache
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

    def launched_features_list
      record.all_launched_features.tap do |lp_features|
        if record.subscription.trial? || record.suspended?
          lp_features.delete :trial_subscription
        end
      end
    end

    def account_admin?
      User.current.privilege?(:manage_account)
    end

    def organisation_domain
      organisation = record.organisation_from_cache
      organisation.try(:alternate_domain) || organisation.try(:domain)
    end
end
