require 'spec_helper'

describe Support::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
  end

  before(:each) do
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

  it "should mark a ticket as closed" do
    test_subject = Faker::Lorem.sentence(4)
    test_user = Factory.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => test_subject })
    log_in(test_user)
    get :show, :id => test_ticket.display_id
    post :close, :id => test_ticket.display_id
    test_ticket.reload
    @account.tickets.find_by_display_id(test_ticket.display_id).status.should be_eql(5)
  end

  it "should add emails that need to be copied when a notification for ticket is sent" do
    test_subject = Faker::Lorem.sentence(4)
    test_user = Factory.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    test_cc_email1 = Faker::Internet.email
    test_cc_email2 = Faker::Internet.email
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => test_subject })
    log_in(test_user)
    get :show, :id => test_ticket.display_id
    put :add_people, :id => test_ticket.display_id,
                     :helpdesk_ticket => { :cc_email => 
                                           { :cc_emails => [test_cc_email1,test_cc_email2].join(",")
                                           }
                                         }
    test_ticket.reload
    flash[:notice].should be_eql("Email(s) successfully added to CC.")
    response.should redirect_to "support/tickets/#{test_ticket.display_id}"
    @account.tickets.find_by_display_id(test_ticket.display_id).cc_email[:cc_emails].should be_eql([test_cc_email1,test_cc_email2])

  end
  it "should filter only closed tickets in list view" do
    test_user = Factory.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    open_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    closed_ticket = create_ticket({ :status => 5, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    log_in(test_user)

    get :filter, :wf_filter => "resolved_or_closed", :wf_order => "status", :wf_order_type => "asc"

    response.should render_template 'support/tickets/_ticket_list.html.erb'
    response.body.should =~ /#{closed_ticket.subject}/
    response.body.should_not =~ /#{open_ticket.subject}/
  end

  it "should call configure export" do
    test_user = Factory.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    log_in(test_user)

    get :configure_export

    response.should render_template 'support/tickets/configure_export.html.erb'
    response.body.should =~ /Filter tickets created in/
  end

  it "should export a ticket csv file" do 
    test_user = Factory.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    open_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    closed_ticket = create_ticket({ :status => 5, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    log_in(test_user)

    start_date = Date.parse((Time.now - 2.day).to_s).strftime("%d %b, %Y");
    end_date = Date.parse((Time.now).to_s).strftime("%d %b, %Y");

    post :export_csv, :data_hash => "", :format => "csv", :date_filter => 30, :start_date => "#{start_date}",
                      :end_date => "#{end_date}", :export_fields => { :display_id => "Ticket Id",
                                                                      :subject => "Subject",
                                                                      :description => "Description",
                                                                      :status_name => "Status",
                                                                      :requester_name => "Requester Name",
                                                                      :requester_info => "Requester Email",
                                                                      :responder_name => "Agent",
                                                                      :created_at => "Created Time",
                                                                      :updated_at => "Last Updated Time"
                      }
    response.content_type.should be_eql("text/csv")
    response.headers["Content-Disposition"].should be_eql("attachment; filename=tickets.csv")
  end
end