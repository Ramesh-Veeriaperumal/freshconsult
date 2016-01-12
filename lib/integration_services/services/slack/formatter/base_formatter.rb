module IntegrationServices::Services::Slack::Formatter
  class BaseFormatter

    def initialize(payload, agent_slack_id=nil, requester_slack_id=nil)
      @payload = payload
      @ticket = payload[:act_on_object]
      @agent_slack_id = agent_slack_id
      @requester_slack_id = requester_slack_id
    end

  end
end