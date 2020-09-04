# frozen_string_literal: true

module Billing::ChargebeeOmniUpgradeHelper
  include Billing::Constants
  include Freshchat::AgentUtil
  include Freshcaller::AgentUtil
  include Freshchat::JwtAuthentication
  include Freshcaller::JwtAuthentication
  include OmniChannel::Util

  SUBSCRIPTION_CHANGED = 'subscription_changed'
  PAGE_BREAK_COUNT = 10

  private

    def handle_omni_upgrade_via_chargebee
      eligible_for_upgrade = eligible_for_omni_upgrade?
      revert_to_previous_subscription unless eligible_for_upgrade
      eligible_for_upgrade
    end

    def revert_to_previous_subscription
      Billing::Subscription.new.update_subscription(@account.subscription, false, @account.addons)
    end

    def omni_plan_upgrade?(event_type, content)
      event_type == SUBSCRIPTION_CHANGED && Account.current.chargebee_omni_upgrade_enabled? && omni_plan?(content)
    end

    def omni_plan?(content)
      plan = subscription_plan(content[:subscription][:plan_id])
      omni_bundle_plans = SubscriptionPlan::OMNI_BUNDLE_PLANS
      omni_bundle_plans.include?(plan.name) && omni_bundle_plans.exclude?(Account.current.subscription.plan_name)
    end

    def eligible_for_omni_upgrade?
      org_pre_conditions_satisfied = org_pre_conditions_satisfied?
      agents_pre_conditions_satisfied = org_pre_conditions_satisfied && freshdesk_agents_are_superset_of_freshchat_and_freshcaller_agents?
      unless org_pre_conditions_satisfied && agents_pre_conditions_satisfied
        Rails.logger.info "Chargebee Omni upgrade requirement failed :: #{Account.current.id} :: #{org_pre_conditions_satisfied} :: #{agents_pre_conditions_satisfied}"
        return false
      end
      true
    rescue StandardError => e
      Rails.logger.error "Exception in finding omni upgrade eligiblity :: Account ID: #{Account.current.id} :: Error message: #{e.message} :: #{e.backtrace[0..20]}"
      false
    end

    def org_pre_conditions_satisfied?
      freshchat_and_freshcaller_integrated? && integrated_accounts_present_in_org?
    end

    def integrated_accounts_present_in_org?
      existing_current_user = User.current
      get_freshid_org_admin_user(Account.current).make_current
      check_if_freshchat_and_freshcaller_present_in_same_org
    rescue StandardError => e
      Rails.logger.error "Exception in finding organisation accounts :: Account ID: #{Account.current.id} :: Error message: #{e.message} :: #{e.backtrace[0..20]}"
      false
    ensure
      existing_current_user.make_current if existing_current_user.present?
    end

    def check_if_freshchat_and_freshcaller_present_in_same_org
      org_domain = Account.current.organisation.domain
      fch_domain = Account.current.freshchat_account.domain
      fcl_domain = Account.current.freshcaller_account.domain
      page_counter = 1
      fch_present = false
      fcl_present = false
      fch_fcl_present = false
      loop do
        organisation_accounts = Account.current.organisation_accounts(org_domain, page_counter)
        if organisation_accounts.present?
          organisation_domains = organisation_accounts[:accounts].map { |account_detail| account_detail[:domain] }
          fch_present ||= organisation_domains.include?(fch_domain)
          fcl_present ||= organisation_domains.include?(fcl_domain)
          fch_fcl_present = fch_present && fcl_present
          if organisation_accounts[:page_number] == PAGE_BREAK_COUNT
            Rails.logger.info "Organisation accounts fetch page limit reached for account :: #{Account.current.id} "
            break
          end
        end
        break if freshchat_freshcaller_present_or_no_more_org_accounts(fch_fcl_present, organisation_accounts)

        page_counter += 1
      end
      fch_fcl_present
    end

    def freshchat_freshcaller_present_or_no_more_org_accounts(fch_fcl_present, org_accounts)
      fch_fcl_present || org_accounts.blank? || org_accounts[:has_more].blank?
    end

    def freshchat_and_freshcaller_integrated?
      Account.current.freshid_org_v2_enabled? && Account.current.freshchat_account_present? && Account.current.freshcaller_account_present?
    end

    def freshdesk_agents_are_superset_of_freshchat_and_freshcaller_agents?
      fd_agents = Account.current.full_time_support_agents
      fd_agent_emails = fd_agents.map { |agent| agent.user.email if agent.user.present? }
      fd_agents_are_superset_of_fch_agents?(fd_agent_emails) && fd_agents_are_superset_of_fcl_agents?(fd_agent_emails)
    end

    def fd_agents_are_superset_of_fch_agents?(fd_agent_emails)
      fch_agent_emails = fetch_freshchat_agent_emails
      fch_fd_diff = fch_agent_emails - fd_agent_emails
      fch_fd_diff.empty?
    end

    def fd_agents_are_superset_of_fcl_agents?(fd_agent_emails)
      fcl_agent_emails = fetch_freshcaller_agent_emails
      fcl_fd_diff = fcl_agent_emails - fd_agent_emails
      fcl_fd_diff.empty?
    end
end
