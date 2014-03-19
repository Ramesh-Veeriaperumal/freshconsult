require 'spec_helper'

describe Helpdesk::TicketsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
    @test_ticket = create_ticket({ :status => 2 }, create_group(@account, {:name => "Tickets"}))
    @group = @account.groups.first
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
  end

  it "should not create a new ticket without the required fields" do
    now = (Time.now.to_f*1000).to_i
    post :create, :helpdesk_ticket => {:email => "",
                                       :requester_id => "", 
                                       :subject => "#{now}", 
                                       :ticket_type => "Question", 
                                       :source => "3", 
                                       :status => "2", 
                                       :priority => "1", 
                                       :group_id => "", 
                                       :responder_id => "", 
                                       :ticket_body_attributes => {"description_html"=>"<p>Testing</p>"}
                                      }
    response.body.should =~ /Requester should be a valid email address/
    @account.tickets.find_by_subject("#{now}").should be_nil
  end

  it "should not allow a restricted agent to access other agents' tickets" do
    restricted_user = add_agent(@account, { :name => Faker::Name.name, 
                                            :email => Faker::Internet.email, 
                                            :active => 1, 
                                            :role => 1, 
                                            :agent => 1,
                                            :ticket_permission => 3,
                                            :role_ids => ["#{@account.roles.first.id}"] })
    global_agent_ticket = create_ticket({ :status => 2 }, @group)
    global_agent_ticket.update_attributes(:responder_id => @user.id)
    log_in(restricted_user)
    get :show, :id => @test_ticket.display_id
    @request.env['HTTP_REFERER'] = 'sessions/new'
    put :close_multiple, { :id => "multiple", :ids => [global_agent_ticket.display_id] }

    # This test will fail. No check in place.
    @account.tickets.find(global_agent_ticket.id).status.should be_eql(2)
  end
end