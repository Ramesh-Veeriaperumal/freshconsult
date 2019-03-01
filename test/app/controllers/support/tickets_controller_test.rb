require_relative '../../../api/test_helper'
require_relative '../../../core/helpers/controller_test_helper'
require_relative '../../../core/helpers/tickets_test_helper'
require_relative '../../../core/helpers/users_test_helper'
require_relative '../../../api/helpers/privileges_helper'
require_relative '../../../api/helpers/archive_ticket_test_helper'

class Support::TicketsControllerTest < ActionController::TestCase
  include ControllerTestHelper
  include TicketsTestHelper
  include UsersTestHelper
  include PrivilegesHelper
  include ArchiveTicketTestHelper
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
  	get :filter, :version => :private
  	assert_response 200
  	assert response.body.include? "Open or Pending : #{Account.current.portal_name}"

  	# get :filter, :version => :private, :wf_filter => "all" 
  	# assert_response 200
  	# assert response.body.include? "All Tickets : #{Account.current.portal_name}"
    log_out
    user.destroy
  end


  def test_close
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	post :close, :version => :private, id: t1.id
  	assert_response 302
  	assert user.tickets.find(t1.id).status == 5
  	assert_equal flash[:notice], "Your ticket has been successfully closed."

  	t2 = create_ticket(requester_id: user.id)
  	Helpdesk::Ticket.any_instance.stubs(:update_attribute).returns(false)
  	post :close, :version => :private, id: t2.id
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
  	put :add_people, :version => :private, id: t1.id, :helpdesk_ticket => { :cc_email => { :reply_cc => Faker::Internet.email }}
  	assert_response 302
  	assert_equal flash[:notice], "Email(s) successfully added to CC."
    t1.destroy

    t1 = create_ticket(requester_id: user.id)
    put :add_people, :version => :private, id: t1.id, :helpdesk_ticket => { :cc_email => { :reply_cc => Faker::Internet.email }}
    assert_response 302
    assert_equal flash[:notice], "Email(s) successfully added to CC."

  	email_array = []
  	60.times { email_array << Faker::Internet.email}
  	put :add_people, :version => :private, id: t1.id, :helpdesk_ticket => { :cc_email => {:reply_cc => email_array}}
  	assert_response 302
  	assert_equal flash[:error], "You can add upto 50 CC emails"

  	log_out
  	user.destroy
    t1.destroy
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
  	put :update, :version => :private, :helpdesk_ticket => { :subject => "test subject" }, id: t1.id
  	assert_response 302
    assert flash[:notice], "The ticket has been updated"
    # Helpdesk::Ticket.any_instance.unstub(:update_attribute)
  	log_out
  	user.destroy
    t1.destroy
  end

  def test_show
  	user = add_new_user(Account.current, active: true)
  	user.make_current
  	t1 = create_ticket(requester_id: user.id)
  	login_as(user)
  	get :show, :version => :private, id: t1.id
  	assert_response 200

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
    get :index, :version => :private, requested_by: User.first
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
    get :show, :version => :private, id: @archive_ticket.id
    assert_response 302
    log_out
    cleanup_archive_ticket(@archive_ticket, {conversations: true})
    user.destroy
  end
end