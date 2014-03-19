require 'spec_helper'

describe Support::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = @account.users.find_by_email("customer@customer.in")
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    log_in(@user)
  end

  it "should create a new ticket" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => "rachel@freshdesk.com", 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    @account.tickets.find_by_subject(test_subject).should be_an_instance_of(Helpdesk::Ticket)
  end

  it "should view tickets of users in the same company" do
    test_subject = Faker::Lorem.sentence(4)
    company = Factory.build(:customer, :name => Faker::Name.name)
    company.save
    test_user1 = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                               :user_role => 3, :customer_id => company.id, 
                               :privileges => (Role.first.privileges.to_i + 1).to_s)
    test_user1.save
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user1.id, :subject => test_subject }, 
                                  create_group(@account, {:name => "Tickets"}))
    test_user2 = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user2.save
    log_in(test_user1)
    get :index
    response.should render_template 'support/tickets/index.portal'
    get :show, :id => test_ticket.display_id
    response.should render_template 'support/tickets/show.portal'
    response.body.should =~ /#{test_subject}/
  end
end