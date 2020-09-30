require_relative '../test_helper'
class ApiAttachmentsControllerTest < ActionController::TestCase
  include AttachmentsTestHelper
  include TicketHelper
  include GroupHelper
  include Redis::RedisKeys
  include Redis::OthersRedis

  def wrap_cname(params)
    { attachment: params }
  end

  def setup
    super
    @request.env['CONTENT_TYPE'] = 'multipart/form-data'
  end

  def teardown
    super
    # Agent fetch for test cases has a check for all ticket permission, so updating it as a failsafe
    user = User.current
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets])
  end

  def test_destroy_attachment_without_ticket_privilege
    ticket_id = create_ticket.display_id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    User.any_instance.stubs(:privilege?).with(:manage_tickets).returns(false)
    delete :destroy, controller_params(id: attachment.id)
    User.any_instance.unstub(:privilege?)
    assert_response 403
  end

  def test_destroy_attachment_without_ticket_permission
    ticket_id = create_ticket.display_id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    User.any_instance.stubs(:has_ticket_permission?).returns(false)
    delete :destroy, controller_params(id: attachment.id)
    User.any_instance.unstub(:has_ticket_permission?)
    assert_response 403
  end

  def test_destroy_attachment_with_all_ticket_permission
    user = User.current
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:all_tickets])
    ticket_id = create_ticket.id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 204
  end

  def test_destroy_attachment_with_assigned_ticket_permission
    user = User.current
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    ticket_id = create_ticket(responder_id: user.id).id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 204
  end

  def test_destroy_attachment_with_group_ticket_permission
    user = User.current
    group = create_group_with_agents(Account.current, agent_list: [user.id])
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    ticket_id = create_ticket({}, group).id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 204
  end

  def test_destroy_attachment_without_assigned_ticket_permission
    user = User.current
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets])
    ticket_id = create_ticket.id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 403
  end

  def test_destroy_attachment_without_group_ticket_permission
    user = User.current
    user.agent.update_attributes(ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets])
    ticket_id = create_ticket.id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 403
  end

  def test_destroy_attachment_with_shared_attachments
    ticket = create_ticket
    create_shared_attachment(ticket)
    attachment = ticket.attachments_sharable.first
    delete :destroy, controller_params(id: attachment.id)
    assert_response 403
  end

  def test_destroy_user_draft_attachment
    attachment = create_attachment(attachable_type: 'UserDraft', attachable_id: @agent.id)
    user_draft_redis_key = format(MULTI_FILE_ATTACHMENT, date: Time.now.utc.strftime('%Y-%m-%d'))
    member_value = "#{@account.id}:#{attachment.id}"
    add_member_to_redis_set(user_draft_redis_key, member_value)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 204
    assert_equal false, get_all_members_in_a_redis_set(user_draft_redis_key).include?(member_value)
  end

  def test_destroy_ticket_attachment
    ticket_id = create_ticket.display_id
    attachment = create_attachment(attachable_type: 'Helpdesk::Ticket', attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 204
  end

  def test_destroy_non_existent_attachment
    invalid_attachment_id = Helpdesk::Attachment.last.id + 100
    delete :destroy, controller_params(id: invalid_attachment_id)
    assert_response 404
  end

  def test_destroy_file_ticket_field_attachment
    ticket_id = create_ticket.display_id
    attachment = create_attachment(attachable_type: AttachmentConstants::FILE_TICKET_FIELD, attachable_id: ticket_id)
    delete :destroy, controller_params(id: attachment.id)
    assert_response 400
    match_custom_json(JSON.parse(response.body), request_error_pattern(:cannot_delete_file_ticket_field_attachment))
  end
end
