require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/tickets_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'

class Support::NotesControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include CoreTicketsTestHelper
  include UsersTestHelper
  include PrivilegesHelper


  def setup
    Account.any_instance.stubs(:current).returns(Account.first)
    @account = Account.current
    super
  end

  def teardown
    Account.unstub(:current)
    super
  end

  def test_create
  	user = add_new_user(Account.current, :active => true)
    user.make_current
    t1 = create_ticket(:requester_id => user.id)
    Helpdesk::Ticket.stubs(:find_by_param).returns(Account.first.tickets.last)
    login_as(user)
    post :create, :version => :private, ticket_id: t1.display_id, :helpdesk_note => { :note_body_attributes => { :body_html => "Hi Hello" }}
    assert_response 302
    assert flash[:notice], "The note has been added to your ticket."

    post :create, :version => :private, ticket_id: t1.display_id, :helpdesk_note => { :note_body_attributes => { :body_html => "Hi Hello how are you" }}, format: 'mobile'
    assert_response 200
    assert JSON.parse(response.body)["success"] == true
    log_out
    user.destroy
    t1.destroy
  end

  def test_create_save_fail
  	user = add_new_user(Account.current, :active => true)
    user.make_current
    t1 = create_ticket(:requester_id => user.id)
    Helpdesk::Ticket.stubs(:find_by_param).returns(Account.first.tickets.last)
    login_as(user)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
    post :create, :version => :private, ticket_id: t1.display_id, :helpdesk_note => { :note_body_attributes => { :body_html => "Hi Hello" }}
    assert_response 302
    # assert flash[:notice], "The note has been added to your ticket."
    Helpdesk::Note.any_instance.unstub(:save_note)
    log_out
    user.destroy
    t1.destroy
  end

  def test_create_access_fail
  	user = add_new_user(Account.current, :active => true)
    user.make_current
    user1 = add_new_user(Account.current, :active => true)
    remove_privilege(user, :manage_tickets)
    t1 = create_ticket(:requester_id => user1.id)
    Helpdesk::Ticket.stubs(:find_by_param).returns(Account.first.tickets.last)
    login_as(user)
    post :create, :version => :private, ticket_id: t1.display_id, :helpdesk_note => { :note_body_attributes => { :body_html => "Hi Hello" }}
    assert_response 302
    log_out
    user.destroy
    t1.destroy
  end

  def test_create_access_fail_with_nil_user
    user1 = add_new_user(Account.current, { active: true })
    t1 = create_ticket(requester_id: user1.id)
    Helpdesk::Ticket.stubs(:find_by_param).returns(Account.first.tickets.last)
    @controller.stubs(:current_user).returns(nil)
    post :create, :version => :private, ticket_id: t1.display_id, :helpdesk_note => { :note_body_attributes => { :body_html => 'Hi Hello' } }
    assert_response 302
    t1.destroy
  end
end