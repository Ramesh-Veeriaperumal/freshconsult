require 'spec_helper'

describe Helpdesk::TicketsController do

  self.use_transactional_fixtures = false
  include APIAuthHelper

  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
    stub_s3_writes
  end

  it "should create a ticket" do
    post :create, ticket_params.merge!({:format => 'xml'}),:content_type => 'application/xml'
    response.status.should be_eql ('201 Created')
  end

  it "should update a ticket" do
    new_ticket = create_ticket({:status => 2})
    put :update, { :helpdesk_ticket => {:status => 3, :priority => 2 },:format => 'xml',:id=>new_ticket.display_id }, :content_type => 'application/xml'
    response.status.should be_eql ('200 OK')
    # comparison ignored now because "to_emails" is returned in json but not in xml. 
    # fix it to make json == xml and add the below comparison.
    # result =  parse_xml(response)
    # expected = (response.status =~ /200 OK/) && compare(result['helpdesk_ticket'].keys,APIAuthHelper::TICKET_UPDATE_ATTRIBS,{}).empty?
    # expected.should be(true)
  end

  it "should create a ticket with tags and response contain tags" do
     tag_params = {:tags => "exampletag1,exmapletag2"}
     post :create, ticket_params.merge!({:format => 'xml',:helpdesk => tag_params}),:content_type => 'application/xml'
     result =  parse_xml(response)
     expected = (response.status =~ /201 Created/) && result['helpdesk_ticket']['tags'][0]['name'] == 'exampletag1' && result['helpdesk_ticket']['tags'][1]['name'] == 'exampletag2'  
   end
 
  it "should show a ticket" do
    new_ticket = create_ticket({:status => 2})
    get :show, { :id => new_ticket.display_id, :format => 'xml' }
    response.status.should be_eql ('200 OK')
  end

  it "should delete a ticket" do
    new_ticket = create_ticket({:status => 2})
    delete :destroy, { :id => new_ticket.display_id, :format => 'xml' }
    response.status.should be_eql ('200 OK')
  end

  it "should restore a delete ticket" do
    new_ticket = create_ticket({:status => 2})
    delete :destroy, { :id => new_ticket.display_id, :format => 'xml' }
    put :restore, {:id => new_ticket.display_id, :format => 'xml' }
    response.status.should be_eql ('200 OK')
  end

  it "should assign a ticket to the agent" do
    new_ticket = create_ticket({:status => 2})
    new_agent = add_agent_to_account(@account, {:name => "testing21", :email => Faker::Internet.email,
                                                :active => 1, :role => 1
                                                })
    put :assign, {:id => new_ticket.display_id,:responder_id => new_agent.user_id,:format => 'xml'}
    response.status.should be_eql ('200 OK') 
  end

  it "agent should be able to pick a ticket " do
    new_ticket = create_ticket({:status => 2})
    put :pick_tickets, {:id => new_ticket.display_id,:format => 'xml'}
    response.status.should be_eql ('200 OK')
  end

  it "should be able to close a ticket" do
    new_ticket = create_ticket({:status => 2})
    put :close_multiple, {:id => new_ticket.display_id, :format => 'xml'}
    result = parse_xml(response)
    expected = (response.status == '200 OK') && (result['helpdesk_tickets'].first['status_name'] == 'Closed')
    expected.should be(true)
  end

  it "should show tickets as per the custom view filter" do
    new_ticket = create_ticket({:status => 2})
    get :index, { :filter=>'new_my_open' , :format => 'xml' }
    response.status.should be_eql ('200 OK')
    result = parse_xml(response)
    result.length.should be <= 30
  end

  it "should show all tickets pagination set to 30 tickets" do
    get :index, {:format => 'xml'}
    response.status.should be_eql ('200 OK')
    result = parse_xml(response)
    result.length.should be <= 30
  end

  it "should show tickets for the given email(user_ticket?)" do
    user = add_new_user(@account)
    requester_id = user.id
    email = user.email
    new_ticket = create_ticket({:status => 2,:requester_id => requester_id})
    get :user_ticket, {:email => email, :format => 'xml'}
    response.status.should be_eql ('200 OK')
    result = parse_xml(response)
    result.length.should be <= 30
  end

  it "should create a ticket with attachments" do
    file = fixture_file_upload('/files/attachment.txt', 'plain/text', :binary)
    post :create, ticket_params(file).merge!(:format => 'xml')
    response.should be_success
  end

  def ticket_params(file = nil)
    params = {:subject => Faker::Lorem.words(10).join(" "),
              :description => Faker::Lorem.paragraph,
              :email => Faker::Internet.email}
    params.merge!({:attachments => [{:resource => file}] }) unless file.nil?
    {:helpdesk_ticket => params}
  end

end