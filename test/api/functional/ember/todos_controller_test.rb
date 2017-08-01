require_relative '../../test_helper'
module Ember
  class TodosControllerTest < ActionController::TestCase
    include TicketsTestHelper
    include TodosTestHelper
    include AgentHelper

    def wrap_cname(params)
      { todo: params }
    end

    def setup
      super
      @private_api = true
      @api_params = { version: 'private' }
    end

    def scoper
      Helpdesk::Reminder
    end

    def test_create_todo
      ticket = create_ticket
      todo = { body: 'Ticket todo 1', ticket_id: ticket.display_id }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      match_json(todo_pattern(Helpdesk::Reminder.last))
      match_json(todo_pattern(Helpdesk::Reminder.last, todo))
    end

    def test_create_multiple_todo_in_ticket
      ticket = create_ticket
      @ticket = ticket
      rand(2..5).times do
        todo = { body: 'Ticket todo 1', ticket_id: ticket.display_id }
        post :create, construct_params(@api_params.merge(todo), false)
        assert_response 200
        match_json(todo_pattern(Helpdesk::Reminder.last))
        match_json(todo_pattern(Helpdesk::Reminder.last, todo))
      end
    end

    def test_create_personal_todo
      todo = { body: 'Personal todo' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      match_json(todo_pattern(Helpdesk::Reminder.last))
      match_json(todo_pattern(Helpdesk::Reminder.last, todo))
    end

    def test_create_todo_additionalparam
      post :create, construct_params(@api_params.merge(body: 'Test', addparam: 'cool'), false)
      assert_response 400
      match_json(merge_invalid_field_pattern('addparam'))
    end

    def test_create_todo_lengthytext
      post :create, construct_params(@api_params.merge(body: 'Big body text Big body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body textBig body text '), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 'Has 275 characters, it can have maximum of 120 characters'))
    end

    def test_create_todo_emptytext
      post :create, construct_params(@api_params.merge(body: ''), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 'is too short (minimum is 1 characters)'))
    end

    def test_create_todo_without_body
      ticket = create_ticket
      post :create, construct_params(@api_params.merge(ticket_id: ticket.display_id), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 'is too short (minimum is 1 characters)'))
    end

    def test_create_todo_nonexisting_ticketid
      create_ticket # To make sure we have atleast one ticket
      post :create, construct_params(@api_params.merge(body: 'Non existing Id', ticket_id: Helpdesk::Ticket.last.display_id + 10), false)
      assert_response 404
    end

    def test_create_todo_string_ticketid
      post :create, construct_params(@api_params.merge(body: 'String as ticket ID', ticket_id: 'gaass'), false)
      assert_response 404
    end

    def test_create_without_ticket_access
      ticket = create_ticket
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      todo = { body: 'Ticket todo', ticket_id: ticket.display_id }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 403
    ensure
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
    end

    def test_update_with_incorrect_params
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for show', ticket.id)
      put :update, construct_params(@api_params.merge(id: reminder.id), body: Faker::Lorem.sentence, completed: 'ABC')
      assert_response 400
      match_json([bad_request_error_pattern('completed', :datatype_mismatch, expected_data_type: 'Boolean', prepend_msg: :input_received, given_data_type: String)])
    end

    def test_update_todo
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for show', ticket.id)
      put :update, construct_params(@api_params.merge(id: reminder.id), body: Faker::Lorem.sentence, completed: true)
      assert_response 200
      reminder.reload
      match_json(todo_pattern(reminder))
      assert reminder.deleted

      put :update, construct_params(@api_params.merge(id: reminder.id), completed: false)
      assert_response 200
      reminder.reload
      match_json(todo_pattern(reminder))
      assert !reminder.deleted
    end

    def test_update_without_ticket_access
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for update', ticket.id)
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      put :update, construct_params(@api_params.merge(id: reminder.id), body: Faker::Lorem.sentence, completed: true)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_update_other_users_todo
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      reminder = get_new_reminder('Todo for update', nil, new_agent.user.id)
      put :update, construct_params(@api_params.merge(id: reminder.id), body: Faker::Lorem.sentence, completed: true)
      assert_response 403
    end

    def test_show
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for show', ticket.id)
      remove_wrap_params
      get :show, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 200
      match_json(todo_pattern(reminder))
      assert_equal false, reminder.deleted # to check by default completed is false
    end

    def test_show_completed
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for show', ticket.id)
      reminder.toggle(:deleted)
      reminder.save
      remove_wrap_params
      get :show, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 200
      match_json(todo_pattern(reminder))
      assert_equal true, reminder.deleted # to additionally verify  its a  completed todo
    end

    def test_show_without_ticket_access
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      ticket = create_ticket
      reminder = get_new_reminder('Ticket todo for show', ticket.id)
      remove_wrap_params
      get :show, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_show_other_users_todo
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      reminder = get_new_reminder('Todo for show', nil, new_agent.user.id)
      remove_wrap_params
      get :show, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 403
    end

    def test_show_invalid_todo
      get :show, construct_params(@api_params, false).merge(id: scoper.last.id + 10)
      assert_response 404
    end

    def test_index
      remove_wrap_params
      get :index, construct_params(@api_params, false)
      pattern = []
      Helpdesk::Reminder.where(user_id: User.current.id).each do |reminder|
        pattern << todo_pattern(reminder)
      end
      assert_response 200
      match_json(pattern)
    end

    def test_index_with_ticket_id
      remove_wrap_params
      ticket = create_ticket
      pattern = []
      get_new_reminder('todo1', ticket.id)
      get_new_reminder('todo2', ticket.id)
      Helpdesk::Reminder.where(ticket_id: ticket.id).each do |reminder|
        pattern << todo_pattern(reminder)
      end
      get :index, construct_params(@api_params, false).merge(ticket_id: ticket.display_id)
      assert_response 200
      match_json(pattern)
    end

    def test_index_with_invalid_ticket_id
      remove_wrap_params
      get :index, construct_params(@api_params, false).merge(ticket_id: Helpdesk::Ticket.last.display_id + 10)
      assert_response 404
    end

    def test_index_without_ticket_access
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      ticket = create_ticket
      remove_wrap_params
      get :index, construct_params(@api_params, false).merge(ticket_id: ticket.display_id)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_delete
      reminder = get_new_reminder('test delete', nil)
      delete :destroy, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 204
      refute scoper.exists?(reminder.id)
    end

    def test_delete_nonexist_todo
      delete :destroy, construct_params(@api_params, false).merge(id: scoper.last.id + 10)
      assert_response 404
    end

    def test_delete_without_ticket_access
      ticket = create_ticket
      reminder = get_new_reminder('test delete', ticket.id)
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      delete :destroy, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_delete_other_users_todo
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      reminder = get_new_reminder('Todo for show', nil, new_agent.user.id)
      delete :destroy, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 403
    end

    # able to delete a todo
    # should not allow to delete others todo
    # should allow to delete others todo  associated with a ticket he has permission
    # should not allow to delete todos associated with ticket he dont have permission
    # proper error if todo  not present

    # able to toggle his own todo
    # should not allow to toggle others todo
    # should allow to toggle others todo  associated with a ticket he has permission
    # should not allow to toggle others todos associated with ticket he dont have permission
    # proper error if todo not present

    # with out ticket id should return all his todos  (should be properly paginated)
    # wiht ticket id should return all the todos for that ticket
    # with ticket id don't have permisison proper error should be shown
    # with ticket id not present proper error should be shown
    # error should thrown with invalid parameter

    # create with ticketid he has no permission ()
  end
end
