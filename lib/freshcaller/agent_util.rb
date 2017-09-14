module Freshcaller::AgentUtil
  FRESHCALLER_DEFAULT_ROLE = 4  
  include Freshcaller::JwtAuthentication
  def falcon_and_freshcaller_enabled?(agent)
    agent.account.has_feature?(:freshcaller) && agent.account.launched?(:falcon)
  end
  
  def create_update_fc_agent(agent)
    return unless falcon_and_freshcaller_enabled?(agent)
    fc_agent = agent.freshcaller_agent
    if fc_agent.present?
      fc_agent.update_attributes(fc_enabled: agent.freshcaller_enabled.try(:to_bool))
    else
      return if agent.freshcaller_enabled.blank?
      fc_agent = agent.create_freshcaller_agent(fc_enabled: agent.freshcaller_enabled.to_bool)
    end
    add_agent_to_freshcaller(agent) if fc_agent.fc_agent_id.blank?
  end

  def freshcaller_params(agent)
      {"data"=>{"attributes"=>{"name"=>"#{agent.user.name}"}, "relationships"=>{"user_emails"=>{"data"=>[{"id"=>nil, "type"=>"user_emails", "attributes"=>{"email"=>"#{agent.user.email}", "primary_email"=>true}}]}, "roles"=>{"data"=>[{"id"=>FRESHCALLER_DEFAULT_ROLE, "type"=>"roles"}]}}, "role"=>FRESHCALLER_DEFAULT_ROLE, "type"=>"users"}}
  end
  
  def add_agent_to_freshcaller(agent)
    protocol = Rails.env.development? ? 'http://' : 'https://'
    path = "#{protocol}#{::Account.current.freshcaller_account.domain}/users"
    response = freshcaller_request(freshcaller_params(agent), path, :post, { email: ::User.current.email })
    if(response.parsed_response["data"].present?)
      agent_id = response.parsed_response["data"]["id"]
      agent.freshcaller_agent.update_attributes(fc_agent_id: agent_id)
    else
      #failsafe rollback
      agent.freshcaller_agent.destroy
    end
  end
end
