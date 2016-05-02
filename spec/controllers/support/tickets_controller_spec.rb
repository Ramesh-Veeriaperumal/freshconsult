require 'spec_helper'

describe Support::TicketsController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = create_dummy_customer
  end

  before(:each) do
    log_in(@user)
  end

  it "should render new support ticket page" do
    get :new
    response.should render_template 'support/tickets/new'
  end

  it "should not create a new ticket when captcha failed or save_ticket returns false" do
    test_subject = Faker::Lorem.sentence(4)
    Helpdesk::Ticket.any_instance.stubs(:save_ticket).returns(false)
    post :create, { :helpdesk_ticket => { :email => Faker::Internet.email, 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing ticket creation</p>"} 
                                        }, 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\ 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    @account.tickets.find_by_subject(test_subject).should_not be_an_instance_of(Helpdesk::Ticket)
    Helpdesk::Ticket.any_instance.unstub(:save_ticket)
  end

  it "should create a new ticket" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => Faker::Internet.email, 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\ 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    @account.tickets.find_by_subject(test_subject).should be_an_instance_of(Helpdesk::Ticket)
  end

  it "should create a new ticket with cc_emails" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => "rachel@freshdesk.com", 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :cc_emails => "superman@marvel.com,avengers@marvel.com", 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    ticket = @account.tickets.find_by_subject(test_subject)
    ticket.cc_email_hash[:cc_emails].should eql ticket.cc_email_hash[:reply_cc]
  end

  it "should affect reply_cc when adding/removing ticket people to conversation" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => @user.email, 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :cc_emails => "superman@marvel.com,avengers@marvel.com, batman@gothamcity.com", 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    ticket = @account.tickets.find_by_subject(test_subject)
    ticket.cc_email_hash[:reply_cc] = ["superman@marvel.com", "batman@gothamcity.com"]
    ticket.update_attribute(:cc_email, ticket.cc_email_hash)

    put :add_people,  :helpdesk_ticket => { :cc_email => { :reply_cc => "avengers@marvel.com, batman@gothamcity.com, roadrunner@looneytoons.com"}
                                            }, 
                      :id =>ticket.display_id
                      
    ticket.reload.cc_email_hash[:reply_cc].should be_eql(["avengers@marvel.com", "batman@gothamcity.com", "roadrunner@looneytoons.com"])
  end

  it "should affect cc_emails when adding/removing ticket reply cc while adding people" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => @user.email, 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :cc_emails => "superman@marvel.com,avengers@marvel.com, batman@gothamcity.com", 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}}
    ticket = @account.tickets.find_by_subject(test_subject)
    ticket.cc_email_hash[:reply_cc] = ["superman@marvel.com", "batman@gothamcity.com"]
    ticket.update_attribute(:cc_email, ticket.cc_email_hash)

    put :add_people,  :helpdesk_ticket => { :cc_email => { :reply_cc => "avengers@marvel.com, batman@gothamcity.com, roadrunner@looneytoons.com"}
                                            }, 
                      :id =>ticket.display_id

    ticket.reload.cc_email_hash[:cc_emails].should include("roadrunner@looneytoons.com")
  end

  it "should create a new ticket with format - JSON" do
    test_subject = Faker::Lorem.sentence(4)
    post :create, { :helpdesk_ticket => { :email => Faker::Internet.email, 
                                          :subject => test_subject, 
                                          :ticket_body_attributes => { :description_html => "<p>Testing</p>"} 
                                        }, 
                    :meta => { :user_agent => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36\ 
                                              (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36", 
                               :referrer => ""}, :format => 'json'
                 }
    result = JSON.parse(response.body)
    result["success"].should be true
    @account.tickets.find_by_subject(test_subject).should be_an_instance_of(Helpdesk::Ticket)
  end

  it "should view tickets of users in the same company" do
    test_subject = Faker::Lorem.sentence(4)
    company = FactoryGirl.build(:customer, :name => Faker::Name.name)
    company.save
    test_user1 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                               :user_role => 3, :customer_id => company.id, 
                               :privileges => (Role.first.privileges.to_i + 1).to_s)
    test_user1.save
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user1.id, :subject => test_subject }, 
                                  create_group(@account, {:name => "Tickets"}))
    test_user2 = FactoryGirl.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3, :customer_id => company.id)
    test_user2.save
    log_in(test_user1)
    get :index
    response.should render_template 'support/tickets/index'
    get :show, :id => test_ticket.display_id
    response.should render_template 'support/tickets/show'
    response.body.should =~ /#{test_subject}/
  end

  it "should mark a ticket as closed" do
    test_subject = Faker::Lorem.sentence(4)
    test_user = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
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
    test_user = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    test_cc_email1 = Faker::Internet.email
    test_cc_email2 = Faker::Internet.email
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => test_subject })
    log_in(test_user)
    get :show, :id => test_ticket.display_id
    put :add_people, :id => test_ticket.display_id,
                     :helpdesk_ticket => { :cc_email => 
                                           { :reply_cc => [test_cc_email1,test_cc_email2].join(",")
                                           }
                                         }
    test_ticket.reload
    flash[:notice].should be_eql("Email(s) successfully added to CC.")
    response.should redirect_to "/support/tickets/#{test_ticket.display_id}"
    @account.tickets.find_by_display_id(test_ticket.display_id).cc_email[:cc_emails].should be_eql([test_cc_email1,test_cc_email2])
  end


  it "should filter only closed tickets in list view" do
    test_user = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    open_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    closed_ticket = create_ticket({ :status => 5, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    log_in(test_user)

    get :filter, :wf_filter => "resolved_or_closed", :wf_order => "status", :wf_order_type => "asc"

    response.should render_template 'support/tickets/_ticket_list'
    response.body.should =~ /#{closed_ticket.subject}/
    response.body.should_not =~ /#{open_ticket.subject}/
  end

  it "should call configure export" do
    test_user = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
                               :user_role => 3)
    test_user.save
    test_ticket = create_ticket({ :status => 2, :requester_id => test_user.id, :subject => Faker::Lorem.sentence(4) })
    log_in(test_user)

    get :configure_export

    response.should render_template 'support/tickets/configure_export'
    response.body.should =~ /Filter tickets created in/
  end

  it "should export a ticket csv file" do 
    test_user = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email,
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
    response.content_type.should =~ /text\/csv/
    response.headers["Content-Disposition"].should be_eql("attachment; filename=tickets.csv")
  end

  it "should check whether user_email is already exists" do
    request.env["HTTP_ACCEPT"] = "application/json"
    get :check_email, :v => Faker::Internet.email
    item = JSON.parse(response.body)
    item["user_exists"].should be false
    response.should be_success
  end
end