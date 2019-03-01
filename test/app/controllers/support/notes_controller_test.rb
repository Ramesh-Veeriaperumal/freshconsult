require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/tickets_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'

class Support::NotesControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include TicketsTestHelper
  include UsersTestHelper
  include PrivilegesHelper


  def setup
    super
  end

  def test_create
  	user = add_new_user(Account.current, :active => true)
    user.make_current
    t1 = create_ticket(:requester_id => user.id)
    login_as(user)
    post :create, :version => :private, ticket_id: t1.id, :helpdesk_note => { :note_body_attributes => { :body => "Hi Hello" }}
    assert_response 302
    assert flash[:notice], "The note has been added to your ticket."

    post :create, :version => :private, ticket_id: t1.id, :helpdesk_note => { :note_body_attributes => { :body => "Hi Hello how are you" }}, format: 'mobile'
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
    login_as(user)
    Helpdesk::Note.any_instance.stubs(:save_note).returns(false)
    post :create, :version => :private, ticket_id: t1.id, :helpdesk_note => { :note_body_attributes => { :body => "Hi Hello" }}
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
    login_as(user)
    post :create, :version => :private, ticket_id: t1.id, :helpdesk_note => { :note_body_attributes => { :body => "Hi Hello" }}
    assert_response 302
    log_out
    user.destroy
    t1.destroy
  end
end