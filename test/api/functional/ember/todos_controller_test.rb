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

    def get_contacts(count)
      contacts = []
      total_contacts = User.contacts.count
      if total_contacts && total_contacts >= count
        contacts = User.contacts.all(limit: count)
      else
        count.times { contacts.push(add_new_user(@account)) }
      end
      contacts
    end

    def get_ticket
      ticket = @account.tickets.last
      ticket = create_ticket unless ticket
      ticket
    end

    def test_create_ticket_todo
      ticket = get_ticket
      todo = { body: 'Ticket todo 1', rememberable_id: ticket.display_id, type: 'ticket' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      todo[:todo_id] = JSON.parse(response.body)["id"]
      assert_not_nil /^\d+$/.match(todo[:todo_id].to_s), 
        '"id" is either nil or not valid'
      match_json(todo_pattern(todo.merge(ticket_subject: ticket.subject)))
    end

    def test_create_personal_todo
      todo = { body: 'Ticket todo 1' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      todo[:todo_id] = JSON.parse(response.body)["id"]
      assert_not_nil /^\d+$/.match(todo[:todo_id].to_s), 
        '"id" is either nil or not valid'
      match_json(todo_pattern(todo))
    end

    def test_create_contact_todo
      contact = User.contacts.last
      contact = get_contacts(1)[0] unless contact
      todo = { body: 'Contact todo 1', rememberable_id: contact.id, type: 'contact' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      todo[:todo_id] = JSON.parse(response.body)["id"]
      assert_not_nil /^\d+$/.match(todo[:todo_id].to_s), 
        '"id" is either nil or not valid'
      match_json(todo_pattern(todo.merge(company_id: contact.customer_id, 
                                          contact_name: contact.name)))
    end

    def test_create_company_todo
      company = Company.last
      company = create_company unless company
      todo = { body: 'Commpany todo 1', rememberable_id: company.id, type: 'company' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 200
      todo[:todo_id] = JSON.parse(response.body)["id"]
      assert_not_nil /^\d+$/.match(todo[:todo_id].to_s), 
        '"id" is either nil or not valid'
      match_json(todo_pattern(todo.merge(company_name: company.name)))
    end

    def test_create_todo_additionalparam
      post :create, construct_params(@api_params.merge(body: 'Test', 
        addparam: 'cool'), false)
      assert_response 400
      match_json(merge_invalid_field_pattern('addparam'))
    end

    def test_to_respond_validation_error_on_creating_todo_content_greater_than_250
      post :create, construct_params(@api_params.merge(body: 'Big body text Big 
        body textBig body textBig body textBig body textBig body textBig body 
        textBig body textBig body textBig body textBig body textBig body textBig
        body teextBig body textBig body textBig body textBig body textBig body 
        textBig body textBig body textBig body text '), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 
        'Has 311 characters, it can have maximum of 250 characters'))
    end

    def test_to_respond_validation_error_on_creating_todo_with_emptytext
      post :create, construct_params(@api_params.merge(body: ''), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 
        'is too short (minimum is 1 characters)'))
    end

    def test_to_respond_validation_error_on_creating_todo_without_body
      ticket = get_ticket
      post :create, construct_params(@api_params.merge(
        rememberable_id: ticket.display_id, type: 'ticket'), false)
      assert_response 400
      match_json(merge_invalid_value_pattern('body', 
        'is too short (minimum is 1 characters)'))
    end

    def test_create_todo_nonexisting_ticket
      ticket = get_ticket # To make sure we have atleast one ticket
      display_id = ticket.display_id
      ticket.delete
      todo = { body: 'Commpany todo 1', rememberable_id: display_id, 
        type: 'ticket' }
      post :create, construct_params(@api_params.merge(todo), false)
      assert_response 404
    end

    def test_create_todo_nonexisting_contact
      id = (contact = User.contacts.last) ? contact.id : 123  
      contact.delete if contact
      post :create, construct_params(@api_params.merge(body: 'Non existing Id', 
        rememberable_id: id, type: 'contact'), false)
      assert_response 404
    end

    def test_create_todo_nonexisting_company
      id = (company = Company.last) ? company.id : 123  
      company.delete if company
      post :create, construct_params(@api_params.merge(body: 'Non existing Id', 
        rememberable_id: id, type: 'company'), false)
      assert_response 404
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

    def test_exception_on_list_all_ticket_todo_without_ticket_permission
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      todo = { rememberable_id: get_ticket.display_id, type: "ticket" }
      get :index, construct_params(@api_params, false).merge(todo)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_exception_on_create_ticket_todo_without_ticket_permission
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      todo = { body: 'Sample todo data', rememberable_id: get_ticket.display_id, 
        type: 'ticket' }
      post :create, construct_params(@api_params, false).merge(todo)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_exception_on_delete_ticket_todo_without_ticket_permission
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      ticket = get_ticket
      reminder = get_new_reminder('test delete', ticket.display_id)
      todo = { id: reminder.id }
      delete :destroy, construct_params(@api_params, false).merge(todo)
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_exception_on_update_ticket_todo_without_ticket_permission
      User.any_instance.stubs(:has_ticket_permission?).returns(false)
      ticket = get_ticket
      reminder = get_new_reminder('test delete', ticket.display_id)
      put :update, construct_params({ version: 'private', id: reminder.id })
      assert_response 403
    ensure
      User.any_instance.unstub(:has_ticket_permission?)
    end

    def test_update_to_personal_todo
      reminder = get_new_reminder('test delete')
      todo = { body: Faker::Lorem.characters(200) }
      put :update, construct_params({ version: 'private', id: reminder.id }, todo)
      assert_response 200
      match_json(todo_pattern(todo.merge({ todo_id: reminder.id })))
    end

    def test_update_to_ticket_todo
      ticket = get_ticket
      reminder = get_new_reminder('test delete', ticket.display_id)
      todo = { body: Faker::Lorem.characters(200), completed: true }
      put :update, construct_params({ version: 'private', id: reminder.id }, todo)
      assert_response 200
      match_json(todo_pattern(todo.merge(todo_id: reminder.id, type: 'ticket', 
        rememberable_id: ticket.display_id, ticket_subject: ticket.subject)))
    end

    def test_update_to_contact_todo
      contact = User.contacts.last
      contact = get_contacts(1)[0] unless contact
      reminder = get_new_reminder('test delete', nil, contact.id, contact.customer_id)
      todo = { body: Faker::Lorem.characters(200), completed: true }
      put :update, construct_params({ version: 'private', id: reminder.id }, todo)
      assert_response 200
      match_json(todo_pattern(todo.merge(todo_id: reminder.id, type: 'contact', 
        rememberable_id: contact.id, company_id: contact.customer_id, 
        contact_name: contact.name)))
    end

    def test_update_to_company_todo
      company = Company.last
      company = create_company unless company
      reminder = get_new_reminder('test delete', nil, nil, company.id)
      todo = { body: Faker::Lorem.characters(200), completed: true }
      put :update, construct_params({ version: 'private', id: reminder.id }, todo)
      assert_response 200
      match_json(todo_pattern(todo.merge(todo_id: reminder.id, type: 'company', 
        rememberable_id: company.id, company_name: company.name)))
    end

    def test_delete_other_users_todo
      new_agent = add_agent_to_account(@account, name: Faker::Name.name, active: 1, role: 1)
      reminder = get_new_reminder('Todo for show', nil, nil, nil, new_agent.user.id)
      delete :destroy, construct_params(@api_params, false).merge(id: reminder.id)
      assert_response 403
    end

    def test_index_with_invalid_type_param
      get :index, controller_params({
        version: 'private', 
        type: Faker::Lorem.characters(8),
        rememberable_id: 123
      })
      match_json(validation_error_response("type", 
        "It should be one of these values: 'ticket,contact,company'",
        "invalid_value"))
      assert_response 400
    end

    def test_index_missing_id_field_exception
      get :index, controller_params({
        version: 'private', 
        type: 'ticket'
      })
      match_json(validation_error_response("rememberable_id", 
        "It should be a/an Integer",
        "missing_field"))
      assert_response 400
    end

    def validation_error_response(field, message, code)
      { "description" => "Validation failed", 
        "errors"      => [ {  "field"  => field,
                              "message"=> message,
                              "code"   => code
                            } ]
      }
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
