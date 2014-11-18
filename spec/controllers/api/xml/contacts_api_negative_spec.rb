require 'spec_helper'

RSpec.describe ContactsController do

  self.use_transactional_fixtures = false


  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end

  it "should not create a contact without an email" do
  	contact_name = Faker::Lorem.sentence(3)
  	post :create, {:user => {:name => contact_name },:format => 'xml'}, :content_type => 'application/xml'
    # val = error_message(response) && error_status?(response.status)
    #puts "#{response.body} :: #{response.status} "

  	error_status?(response.status).should eql(true)
  end

  it "should not update a contact with an existing/duplicate email" do
		first_contact = add_new_user(@account,{})
		dup_email = first_contact.email
		second_contact = add_new_user(@account,{})
		put :update, {:id => second_contact.id, :user=>{:email => dup_email },:format => 'xml'}, :content_type => 'application/xml'
		# puts "#{response.body} :: #{response.status}"
    # val = error_message(response) && error_status?(response.status)
		error_status?(response.status).should be_truthy
  end

  it "should not accept query params other than email/phone/mobile" do
    contact = add_new_user(@account,{})
    check_name  = contact.name
    get :index, {:query=>"name is #{check_name}", :state=>:all, :format => 'xml'}
    #puts "#{response.body} :: #{response.status}"
    val = query_error(response)
    val.should be_truthy
  end


  def error_status?(status)
      status == 422
   end

   def error_message(message)
    result = parse_xml(message)
    #puts "#{result['errors']['error']}"
    ["Email has already been taken","Email is invalid"].include?(result["errors"]["error"])
   end

   def query_error(message)
    result = parse_xml(message)
    # need to change this when we set this error msg under "error" root node
    # in the api impl.
    #puts "#{result["users"]["error"]}"
    ["Not able to parse the query."].include?(result["users"]["error"])
   end
end