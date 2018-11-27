require_relative '../test_helper'
Dir["#{Rails.root}/test/core/helpers/*.rb"].each { |file| require file }
class TicketsControllerTest < ActionController::TestCase
  include AccountTestHelper
  include SharedOwnershipTestHelper
  include ApiTicketsTestHelper

  def setup
    super
  end

  def wrap_cname(params = {})
    { ticket: params }
  end

  # Test when group restricted agent trying to access the ticket which has been assigned to its group
  def test_group_restricted_agent_authorised_ticket
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 2)
      ticket = create_ticket({:status => @status.status_id}, nil, @internal_group)
      # group_restricted_agent = add_agent_to_group(@internal_agent.id,
      #                                             ticket_permission = 2, role_id = @account.roles.agent.first.id)
      login_as(@internal_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      match_json(so_ticket_pattern({}, ticket))
      assert_response 200
    end
  end
  # Test when group restricted agent trying to access the ticket which has not been assigned to its group
  def test_group_restricted_agent_unauthorised_ticket
    enable_feature(:shared_ownership) do
      ticket = create_ticket
      initialize_internal_agent_with_default_internal_group(ticket_permission = 2)
      group_restricted_agent = add_agent_to_group(@internal_agent.id,
                                                  ticket_permission = 2, role_id = @account.roles.agent.first.id)
      login_as(group_restricted_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 403
    end
  end


  # Test when restricted agent trying to access ticket which has not been assigned to him
  def test_ticket_restricted_agent_unauthorised_ticket
    ticket = create_ticket({:status => 2})
    ticket_restricted_agent = add_agent_to_group(nil,
                                                 ticket_permission = 3, role_id = @account.roles.agent.first.id)
    login_as(ticket_restricted_agent)
    get :show, controller_params(version: 'private', id: ticket.display_id)
    assert_response 403
  end

  def test_ticket_restricted_agent_authorised_ticket
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission =3)
      ticket = create_ticket({:status => @status.status_id,:responder_id => @internal_agent.id}, nil, @internal_group)
      login_as(@internal_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 200
      match_json(so_ticket_pattern({}, ticket))
    end
  end

  def test_ticket_create_with_valid_group_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = {email: Faker::Internet.email, status: @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, internal_agent_id: @internal_agent.id, internal_group_id: @internal_group.id}
      post :create, construct_params({}, params)
      t = Helpdesk::Ticket.last
      match_json(so_ticket_pattern(params, t))
      match_json(so_ticket_pattern({}, t))
      assert_response 201
    end
  end

  def test_ticket_create_with_valid_group_no_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = {email: Faker::Internet.email, status: @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, internal_group_id: @internal_group.id}
      post :create, construct_params({}, params)
      t = Helpdesk::Ticket.last
      match_json(so_ticket_pattern(params, t))
      match_json(so_ticket_pattern({}, t))
      assert_response 201
    end
  end

  def test_ticket_create_with_so_fields_invalid_status
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = {email: Faker::Internet.email, status: 2, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, internal_agent_id: @internal_agent.id, internal_group_id: @internal_group.id}
      post :create, construct_params({}, params)
      expected = {
          description: "Validation failed",
          errors: [
              {
                  field: "internal_agent",
                  message: "Internal Agent does not belong to the specified Group",
                  code: "invalid_value"
              },
              {
                  field: "internal_group",
                  message: "Internal group does not belong to the given status of the ticket",
                  code: "invalid_value"
              }
          ]
      }
      match_json(expected)
      assert_response 400
    end
  end

  def test_ticket_create_with_so_fields_invalid_group
    enable_feature(:shared_ownership) do
      new_group = create_internal_group
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = { email: Faker::Internet.email, status:  @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph,internal_agent_id: @internal_agent.id,internal_group_id: new_group.id }
      post :create, construct_params({}, params)
      expected = {
          description: "Validation failed",
          errors: [
              {
                  field: "internal_agent",
                  message: "Internal Agent does not belong to the specified Group",
                  code: "invalid_value"
              },
              {
                  field: "internal_group",
                  message: "Internal group does not belong to the given status of the ticket",
                  code: "invalid_value"
              }
          ]
      }
      match_json(expected)
      assert_response 400
    end
  end

  def test_ticket_create_with_so_fields_invalid_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = { email: Faker::Internet.email, status:  @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph,internal_agent_id: @responding_agent.id,internal_group_id: @internal_group.id }
      post :create, construct_params({}, params)
      expected = {
          description: "Validation failed",
          errors: [
              {
                  field: "internal_agent",
                  message: "Internal Agent does not belong to the specified Group",
                  code: "invalid_value"
              }
          ]
      }
      match_json(expected)
      assert_response 400
    end
  end

  def test_ticket_create_with_so_no_so_feature
    initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
    params = {email: Faker::Internet.email, status: @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph, internal_agent_id: @internal_agent.id, internal_group_id: @internal_group.id}
    post :create, construct_params({}, params)
    expected = {
        description: "Validation failed",
        errors: [
            {
                field: "internal_group_id",
                message: "The shared_ownership feature is required to support internal_group_id attribute in the request",
                code: "inaccessible_field"
            },
            {
                field: "internal_agent_id",
                message: "The shared_ownership feature is required to support internal_agent_id attribute in the request",
                code: "inaccessible_field"
            }
        ]
    }
    match_json(expected)
    assert_response 400
  end

  def test_ticket_update_so_valid
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      t = create_ticket
      params = {status: @status.status_id, internal_agent_id: @internal_agent.id, internal_group_id: @internal_group.id}
      put :update, construct_params({id: t.display_id}, params)
      assert_response 200
      t.reload
      assert_equal params[:internal_agent_id], t.internal_agent_id
      assert_equal params[:internal_group_id], t.internal_group_id
    end
  end

  def test_ticket_update_so_valid_status_group_agent_mapping
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = { email: Faker::Internet.email, status:  @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph,internal_agent_id: @internal_agent.id,internal_group_id: @internal_group.id   }
      post :create, construct_params({}, params)
      add_another_group_to_status
      add_agent_to_new_group
      t = Helpdesk::Ticket.last
      update_params = {status: @status.status_id, internal_group_id: @another_internal_group.id}
      put :update, construct_params({id: t.display_id}, update_params)
      assert_response 200
      t.reload
      assert_equal params[:internal_agent_id], t.internal_agent_id
      assert_equal update_params[:internal_group_id], t.internal_group_id
    end
  end

  def test_ticket_update_so_valid_status_group_mapping_no_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = { email: Faker::Internet.email, status:  @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph,internal_agent_id: @internal_agent.id,internal_group_id: @internal_group.id   }
      post :create, construct_params({}, params)
      add_another_group_to_status
      t = Helpdesk::Ticket.last
      update_params = {status: @status.status_id, internal_group_id: @another_internal_group.id}
      put :update, construct_params({id: t.display_id}, update_params)
      assert_response 200
      t.reload
      assert_nil t.internal_agent_id
      assert_equal update_params[:internal_group_id], t.internal_group_id
    end
  end

  def test_ticket_update_so_valid_status_no_group_mapping
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      params = { email: Faker::Internet.email, status:  @status.status_id, priority: 2, subject: Faker::Name.name, description: Faker::Lorem.paragraph,internal_agent_id: @internal_agent.id,internal_group_id: @internal_group.id   }
      post :create, construct_params({}, params)
      t = Helpdesk::Ticket.last
      update_params = {status: 2}
      put :update, construct_params({id: t.display_id}, update_params)
      assert_response 200
      t.reload
      assert_nil t.internal_agent_id
      assert_nil t.internal_group_id
    end
  end


  def test_ticket_update_so_invalid
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      t = create_ticket
      params = {status: @status.status_id, internal_agent_id: @responding_agent.id, internal_group_id: @internal_group.id}
      put :update, construct_params({id: t.display_id}, params)
      expected = {
          description: "Validation failed",
          errors: [
              {
                  field: "internal_agent",
                  message: "Internal Agent does not belong to the specified Group",
                  code: "invalid_value"
              }
          ]
      }
      match_json(expected)
      assert_response 400
    end
  end


  # Test when Internal agent has agent restricted access and he is trying to view the ticket of its group which
  # has not been assigned to him
  def test_ticket_access_by_unauthorized_internal_agent
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)

      ticket = create_ticket({:status => @status.status_id}, nil, @internal_group)
      login_as(@internal_agent)
      get :show, controller_params(version: 'private', id: ticket.display_id)
      assert_response 403
    end
  end


  def test_index_without_permitted_tickets_group_only_access
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 2)
      Helpdesk::Ticket.update_all(responder_id: nil)
      get :index, controller_params(per_page: 50)
      assert_response 200
      response = parse_response @response.body
      assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size
      Agent.any_instance.stubs(:ticket_permission).returns(2)
      login_as(@internal_agent)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size

    end
  end


  def test_index_without_permitted_tickets_ticket_only_access
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      Helpdesk::Ticket.update_all(responder_id: nil,internal_group_id: @internal_group.id)
      get :index, controller_params(per_page: 50)
      assert_response 200
      response = parse_response @response.body
      assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size
      Agent.any_instance.stubs(:ticket_permission).returns(3)
      login_as(@internal_agent)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal 0, response.size

    end
  end

  def test_index_permitted_tickets_ticket_only_access
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 3)
      expected = Helpdesk::Ticket.update_all(responder_id: nil,internal_group_id: @internal_group.id,internal_agent_id: @internal_agent.id)
      get :index, controller_params(per_page: 50)
      assert_response 200
      response = parse_response @response.body
      assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size
      login_as(@internal_agent)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal expected, response.size

    end
  end

  def test_index_permitted_tickets_group_only_access
    enable_feature(:shared_ownership) do
      initialize_internal_agent_with_default_internal_group(ticket_permission = 2)
      expected = Helpdesk::Ticket.update_all(responder_id: nil,internal_group_id: @internal_group.id)
      get :index, controller_params(per_page: 50)
      assert_response 200
      response = parse_response @response.body
      assert_equal Helpdesk::Ticket.where(deleted: 0, spam: 0).created_in(Helpdesk::Ticket.created_in_last_month).count, response.size
      login_as(@internal_agent)
      get :index, controller_params
      assert_response 200
      response = parse_response @response.body
      assert_equal expected, response.size

    end
  end

end
