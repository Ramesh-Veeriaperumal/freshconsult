require 'spec_helper'

RSpec.describe ContactsController do

  self.use_transactional_fixtures = false
  
  
  before(:each) do
    request.host = @account.full_domain
    http_login(@agent)
  end
  
  it "should not create a contact without an email" do
  	contact_name = Faker::Lorem.sentence(3)
  	post :create, {:user => {:name => contact_name },:format => 'json'}, :content_type => 'application/json'
  	error_status?(response.status).should be_truthy
  end

  it "should not update a contact with an existing/duplicate email" do
		first_contact = add_new_user(@account,{})
		dup_email = first_contact.email
		second_contact = add_new_user(@account,{})
		put :update, {:id => second_contact.id, :user=>{:email => dup_email },:format => 'json'}, :content_type => 'application/json'
		error_status?(response.status).should be_truthy
  end

     
  it "should not make agent as agent again" do
    contact = add_new_user(@account,{})   
    put :make_agent, {:id => contact.id,:format => 'json'}    
    put :make_agent, {:id => contact.id,:format => 'json'}
    record_not_found_status?(response.status).should be_truthy
  end
 
  def record_not_found_status?(status)
     status == 404
  end

  def error_status?(status)
      status == 422
  end
end