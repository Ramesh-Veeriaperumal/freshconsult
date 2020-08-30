require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/tickets_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'
require_relative '../../../api/helpers/archive_ticket_test_helper'
require "#{Rails.root}/test/core/helpers/note_test_helper"

class Support::TicketsControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include CoreTicketsTestHelper
  include CoreUsersTestHelper
  include PrivilegesHelper
  include ArchiveTicketTestHelper
  include NoteTestHelper

  ARCHIVE_DAYS = 120
  TICKET_UPDATED_DATE = 150.days.ago

  def setup
    super
  end

  def test_index
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	t2 = create_ticket(requester_id: user.id)
  	t3 = create_ticket(requester_id: user.id)
  	login_as(user)
  	get :index, :version => :private
  	assert_response 200
  	assert response.body.include?(t1.subject)
  	assert response.body.include?(t2.subject)
  	assert response.body.include?(t3.subject)
  	log_out
  	user.destroy
  	t1.destroy
  	t2.destroy
  	t3.destroy
  end

  def test_filter
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    t1 = create_ticket(requester_id: user.id)
    get :filter, version: :private
    assert_response 200
    assert response.body.include? t1.subject
    log_out
    user.destroy
    t1.destroy
  end


  def test_close
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	post :close, :version => :private, id: t1.display_id
  	assert_response 302
  	assert user.tickets.find(t1.id).status == 5
  	assert_equal flash[:notice], "Your ticket has been successfully closed."

  	t2 = create_ticket(requester_id: user.id)
  	Helpdesk::Ticket.any_instance.stubs(:update_attribute).returns(false)
  	post :close, :version => :private, id: t2.display_id
  	assert_response 302
  	assert user.tickets.find(t2.id).status == 2
  	assert_equal flash[:notice], "Closing the ticket failed."
  	Helpdesk::Ticket.any_instance.unstub(:update_attribute)
  	log_out
  	user.destroy
  	t1.destroy
  	t2.destroy
  end

  def test_add_people
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id, cc_emails: [Faker::Internet.email] )
  	login_as(user)
  	put :add_people, :version => :private, id: t1.display_id, :helpdesk_ticket => { :cc_email => { :reply_cc => Faker::Internet.email }}
  	assert_response 302
  	assert_equal flash[:notice], "Email(s) successfully added to CC."
    t1.destroy

    t1 = create_ticket(requester_id: user.id)
    put :add_people, :version => :private, id: t1.display_id, :helpdesk_ticket => { :cc_email => { :reply_cc => Faker::Internet.email }}
    assert_response 302
    assert_equal flash[:notice], "Email(s) successfully added to CC."

  	email_array = []
  	60.times { email_array << Faker::Internet.email}
  	put :add_people, :version => :private, id: t1.display_id, :helpdesk_ticket => { :cc_email => {:reply_cc => email_array}}
  	assert_response 302
  	assert_equal flash[:error], "You can add upto 50 CC emails"

  	log_out
  	user.destroy
    t1.destroy
  end

  def test_add_people_invalid_email
    Account.stubs(:current).returns(Account.first || create_test_account)
    Account.any_instance.stubs(:new_email_regex_enabled?).returns(true)
    user = add_new_user(Account.current, active: true)
    user.make_current
    t1 = create_ticket(requester_id: user.id, cc_emails: ['test.@gmail.com'])
    login_as(user)
    put :add_people, version: :private, id: t1.display_id, helpdesk_ticket: { cc_email: { reply_cc: %w[test1.@gmail.com test2@gmail.com] } }
    t1.reload
    assert_includes t1.cc_email[:reply_cc], 'test2@gmail.com'
    refute_includes t1.cc_email[:reply_cc], 'test1.@gmail.com'
    assert_response 302
    assert_equal flash[:notice], 'Email(s) successfully added to CC.'

    log_out
    user.destroy
    t1.destroy
  ensure
    Account.any_instance.unstub(:new_email_regex_enabled?)
    Account.unstub(:current)
  end

  def test_export_csv
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	post :export_csv, :version => :private, :format => 'csv', :date_filter => 30, :export_fields =>  {:display_id => 'Ticket Id', subject: 'Subject', status_name: 'Status', requester_info: 'Requester Email'}
  	assert_response 200

  	log_out
  	user.destroy
    t1.destroy
  end

  def test_configure_export
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	get :configure_export, :version => :private
  	assert_response 200

  	log_out
  	user.destroy
    t1.destroy
  end

  def test_update
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
    # Helpdesk::Ticket.any_instance.stubs(:update_ticket_attributes).returns(true)
  	put :update, :version => :private, :helpdesk_ticket => { :subject => "test subject" }, id: t1.display_id, format: 'json'
  	assert_response 200
    assert flash[:notice], "The ticket has been updated"
    # Helpdesk::Ticket.any_instance.unstub(:update_attribute)
  	log_out
  	user.destroy
    t1.destroy
  end

  def test_update_with_svg_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    t1 = create_ticket(requester_id: user.id)
    login_as(user)
    put :update, version: :private, helpdesk_ticket: { subject: 'test subject', ticket_type: "Question<svg/onload=alert('XSS')>" }, id: t1.display_id
    assert_response 200
    assert response.message, 'invalid_ticket_type'
    log_out
    user.destroy
    t1.destroy
  end

  def test_update_with_svg_ticket_type_nil
    user = add_new_user(Account.current, active: true)
    user.make_current
    t1 = create_ticket(requester_id: user.id)
    login_as(user)
    put :update, version: :private, helpdesk_ticket: { subject: 'test subject', ticket_type: nil }, id: t1.display_id, format: 'json'
    assert_response 200
    assert flash[:notice], 'The ticket has been updated'
  ensure
    log_out
    user.destroy
    t1.destroy
  end

  def test_update_with_svg_ticket_type_empty
    user = add_new_user(Account.current, active: true)
    user.make_current
    t1 = create_ticket(requester_id: user.id)
    login_as(user)
    put :update, version: :private, helpdesk_ticket: { subject: 'test subject', ticket_type: '' }, id: t1.display_id, format: 'json'
    assert_response 200
    assert flash[:notice], 'The ticket has been updated'
  ensure
    log_out
    user.destroy
    t1.destroy
  end

  def test_show
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	get :show, :version => :private, id: t1.display_id
  	assert_response 200

  	log_out
  	user.destroy
    t1.destroy
  end


  def test_show_with_jumbled_order
  	user = add_new_user(Account.current, active: true)
  	user.make_current
    t1 = create_ticket(requester_id: user.id)
    note1 = create_note
    note2 = create_note
    # making note1.id < note2.id and note1.created_at > note2.created_at
    note2.update_attribute(:created_at, Date.yesterday)
  	login_as(user)
  	get :show, :version => :private, id: t1.display_id
  	assert_response 200
    assert response.body.index(note2.body) < response.body.index(note1.body)
    log_out
  	user.destroy
    t1.destroy
  end


  def test_contractor_user
    agent = add_agent(Account.current)
    user = add_new_user(Account.current, active: true)
    company = Account.current.companies.create(name: Faker::Name.name)
    Account.current.user_companies.create(company_id: company.id, user_id: user.id)

    t1 = create_ticket(requester_id: agent.id)
    user.make_current
    login_as(user)
    User.any_instance.stubs(:contractor?).returns(true)
    User.any_instance.stubs(:privilege?).returns(true)
    get :index, :version => :private
    assert_response 200
    User.any_instance.unstub(:contractor?)
    User.any_instance.unstub(:privilege?)
    log_out
    user.destroy
    agent.destroy
    company.destroy
    t1.destroy
  end

  def test_client_manager
    company = Account.current.companies.create(name: Faker::Name.name)
    agent = add_agent(Account.current)
    user = add_new_user(Account.current, active: true)
    Account.current.user_companies.create(company_id: company.id, user_id: user.id, default: 1, client_manager: 1)

    t1 = create_ticket(requester_id: agent.id)
    user.make_current
    login_as(user)
    get :index, :version => :private
    assert_response 200
    log_out
    user.destroy
    agent.destroy
    company.destroy
    t1.destroy
  end

  def test_requested_by
    company = Account.current.companies.create(name: Faker::Name.name)
    agent = add_agent(Account.current)
    user = add_new_user(Account.current, active: true)
    Account.current.user_companies.create(company_id: company.id, user_id: user.id, default: 1, client_manager: 1)

    t1 = create_ticket(requester_id: agent.id)
    user.make_current
    login_as(user)
    get :index, :version => :private, requested_by: Account.current.users.first
    assert_response 200
    log_out
    user.destroy
    agent.destroy
    company.destroy
    t1.destroy
  end

  def test_create
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, :version => :private, :helpdesk_ticket => { :email => user.email } , :cc_emails => Faker::Internet.email
    assert_response 302

    Account.any_instance.stubs(:restricted_helpdesk?).returns(true)
    post :create, :version => :private, :helpdesk_ticket => { :email => "" } , :cc_emails => Faker::Internet.email
    assert_response 200
    Account.any_instance.unstub(:restricted_helpdesk?)

    log_out
    user.destroy
  end

  def test_create_ticket_for_login_user_with_feature_enabled_with_diff_email
    @account.add_feature(:prevent_ticket_creation_for_others)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, :version => :private, :helpdesk_ticket => { :email => Faker::Internet.email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal user.email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  ensure
    @account.remove_feature(:prevent_ticket_creation_for_others)
  end

  def test_create_ticket_for_login_user_with_feature_enabled
    @account.add_feature(:prevent_ticket_creation_for_others)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, :version => :private, :helpdesk_ticket => { :email => user.email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal user.email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  ensure
    @account.remove_feature(:prevent_ticket_creation_for_others)

  end

  def test_create_ticket_for_login_user_with_feature_disabled
    @account.remove_feature(:prevent_ticket_creation_for_others)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, :version => :private, :helpdesk_ticket => { :email => user.email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal user.email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  end

  def test_create_ticket_for_login_user_with_feature_disabled_and_diff_email
    @account.remove_feature(:prevent_ticket_creation_for_others)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    email = Faker::Internet.email
    post :create, :version => :private, :helpdesk_ticket => { :email => email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  end

  def test_create_ticket_for_login_user_without_anonymous_tickets_and_with_prevent_ticket_creation_for_others_feature
    @account.add_feature(:prevent_ticket_creation_for_others)
    @account.remove_feature(:anonymous_tickets)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    email = Faker::Internet.email
    post :create, :version => :private, :helpdesk_ticket => { :email => email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal user.email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  ensure
    @account.remove_feature(:prevent_ticket_creation_for_others)
  end

  def test_create_ticket_for_login_user_without_anonymous_tickets_feature_and_without_prevent_ticket_creation_for_others_feature
    @account.remove_feature(:prevent_ticket_creation_for_others)
    @account.remove_feature(:anonymous_tickets)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    email = Faker::Internet.email
    post :create, :version => :private, :helpdesk_ticket => { :email => email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  end

  def test_create_ticket_for_login_user_with_anonymous_tickets_feature_and_with_prevent_ticket_creation_for_others_feature
    @account.add_feature(:prevent_ticket_creation_for_others)
    @account.add_feature(:anonymous_tickets)
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    email = Faker::Internet.email
    post :create, :version => :private, :helpdesk_ticket => { :email => email, :subject => Faker::Name.name }
    ticket = @account.tickets.last
    assert_equal email, @account.users.find(ticket.requester_id).email
    log_out
    user.destroy
  ensure
    @account.remove_feature(:anonymous_tickets)
    @account.remove_feature(:prevent_ticket_creation_for_others)
  end

  def test_create_with_svg_ticket_type
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: "Question<svg/onload=alert('XSS')>" }, cc_emails: Faker::Internet.email
    assert_response 200
    assert response.message, 'invalid_ticket_type'
    log_out
    user.destroy
  end

  def test_create_with_ticket_type_empty
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: '' }, cc_emails: Faker::Internet.email
    assert_response 302
    log_out
    user.destroy
  end

  def test_create_with_ticket_type_nil
    user = add_new_user(Account.current, active: true)
    user.make_current
    login_as(user)
    post :create, version: :private, helpdesk_ticket: { email: user.email, ticket_type: nil }, cc_emails: Faker::Internet.email
    assert_response 302
    log_out
    user.destroy
  end

  def test_archive_tickets
    @account.make_current
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: TICKET_UPDATED_DATE,updated_at: TICKET_UPDATED_DATE,create_association: true)
    @account.make_current
    user = @archive_ticket.requester
    user.active = true
    user.save
    user.make_current
    login_as(user)
    get :show, :version => :private, id: @archive_ticket.display_id
    assert_response 302
    log_out
    cleanup_archive_ticket(@archive_ticket, {conversations: true})
    user.destroy
  end

  def test_verify_attachment_access_for_requester
    @account.make_current
    group_id1 = Account.current.groups.find_by_name('QA')
    agent1 = add_agent(Account.current, active: true, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets], group_id: group_id1)
    agent1.make_current
    group_id2 = Account.current.groups.find_by_name('Sales')
    agent2 = add_agent(Account.current, active: true, ticket_permission: Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets], group_id: group_id2)
    ticket = create_ticket_with_attachments(requester_id: agent1.id)
    ticket.responder_id = agent2.id
    ticket.save!
    attachment = ticket.attachments.first
    login_as(agent1)
    assert agent1.has_customer_ticket_permission?(ticket)
    assert attachment.can_view_helpdesk_ticket?(ticket)
    log_out
    ticket.destroy
  end

  def test_redirect_to_freshid_on_idle_session_timeout
    Account.current.launch(:idle_session_timeout)
    Account.any_instance.stubs(:freshid_org_v2_enabled?).returns(true)
    @controller.stubs(:web_request?).returns(true)
    controller.session[:last_request_at] = Time.now.to_i - 901
    get :index, version: :private
    assert_response 302
    assert_includes response.redirect_url, '/api/v2/logout'
  ensure
    Account.current.rollback(:idle_session_timeout)
    Account.any_instance.unstub(:freshid_org_v2_enabled?)
    @controller.unstub(:web_request?)
  end
end
