module TicketLoadHelper
  def create_group_agent
    @group = create_group(@account)
    @agent = add_agent_to_account(@account, group_id: @group.id, active: 1, role: 4)
  end

  def initial_agent_load
    append_header
    response = get :task_load, controller_params(version: 'channel/ocr', id: @agent.user_id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    @count = response_body['task_load']
  end

  def initial_group_unassigned_load
    append_header
    response = get :unassigned_tasks, controller_params(version: 'channel/ocr', id: @group.id)
    response_body = JSON.parse response.body.gsub('=>', ':')
    @count = response_body['task_load']
  end

  def destroy_agent_group
    @agent.destroy
    Group.find_by_id(@group.id).destroy
  end
end
