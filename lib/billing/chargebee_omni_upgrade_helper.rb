# frozen_string_literal: true

module Billing::ChargebeeOmniUpgradeHelper
  include Billing::Constants
  include Freshchat::AgentUtil
  include Freshcaller::AgentUtil
  include Freshchat::JwtAuthentication
  include Freshcaller::JwtAuthentication
  SUBSCRIPTION_CHANGED = 'subscription_changed'
  PAGE_BREAK_COUNT = 10

  private

    def omni_plan_upgrade?(event_type, plan)
      event_type == SUBSCRIPTION_CHANGED && Account.current.chargebee_omni_upgrade_enabled? && omni_plan?(plan)
    end

    def omni_plan?(plan)
      omni_bundle_plans = SubscriptionPlan::OMNI_BUNDLE_PLANS
      omni_bundle_plans.include?(plan) && omni_bundle_plans.exclude?(Account.current.subscription.plan_name)
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
      return false unless freshchat_and_freshcaller_integrated?

      org_domain = Account.current.organisation.domain
      fch_domain = Account.current.freshchat_account.domain
      fcl_domain = Account.current.freshcaller_account.domain
      page_counter = 1
      fch_present = false
      fcl_present = false
      loop do
        organisation_accounts = Account.current.organisation_accounts(org_domain, page_counter)
        organisation_domains = organisation_accounts[:accounts].map { |account_detail| account_detail[:domain] }
        fch_present = organisation_domains.include?(fch_domain)
        fcl_present = organisation_domains.include?(fcl_domain)
        if organisation_accounts[:page_number] == PAGE_BREAK_COUNT
          Rails.logger.info "Organisation accounts fetch page limit reached for account :: #{Account.current.id} "
          break
        end
        break unless organisation_accounts[:has_more]

        page_counter += 1
      end
      fch_present && fcl_present
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
