require_relative '../../../test_helper'
module AgentsSandboxHelper
  include UsersTestHelper

  def agents_data(account)
    create_agents_data(account)
  end

  def create_agents_data(account)
    users_data = []
    3.times do
      user = add_test_agent(account)
      users_data << [user.agent.attributes.merge({"action" => 'added', "model" => user.agent.class.name})]
    end
    users_data.flatten
  end
end