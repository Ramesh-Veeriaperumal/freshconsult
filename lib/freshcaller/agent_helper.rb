module Freshcaller
  module AgentHelper
    def freshcaller_limit_reached?
      @agent.errors.messages[:base].try(:include?, :freshcaller_agent_limit)
    end

    def fcagent_already_present?
      @agent.errors.messages[:base].try(:include?, :freshcaller_agent_present)
    end

    def freshcaller_alerts
      if freshcaller_limit_reached?
        flash[:error] = t(:'flash.agents.create.freshcaller_limit', fc_billing_url: '/admin/phone/redirect_to_freshcaller?fc_path=/admin/billing').html_safe
      elsif fcagent_already_present?
        flash[:error] = t(:'flash.agents.create.fcagent_already_present').html_safe
      end
    end
  end
end
