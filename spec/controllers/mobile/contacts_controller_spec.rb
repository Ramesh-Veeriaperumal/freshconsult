require 'spec_helper'

describe ContactsController do
  self.use_transactional_fixtures = false
    
  let(:required_attributes) { [ "id","avatar_url","name","email", "company_name", "phone", "mobile", "job_title", "user_time_zone", "twitter_id" ] }
  let(:params) { {:format =>'json'} }

  before(:each) do
    api_login
  end

  it "should return an user object with valid attributes" do
    get :show, params.merge!(:id => @agent.id)
    user_json = json_response['user'].keys
    user_json.should include_all(required_attributes)
  end

  it "should fail when an user object expects invalid attributes" do
    invalid_required_attributes = "invalid_attribute_12345"
    get :show, params.merge!(:id => @agent.id)
    user_json = json_response['user'].keys
    user_json.should_not include(invalid_required_attributes)
  end

  it "should return all contacts with valid attributes" do
    get :index, params.merge(:state => "all", :page => 1)
    json_response.each do |user_array|
      user_json = user_array['user'].keys
      user_json.should include_all(required_attributes)
    end
  end

  it "should create a contact" do
    post :create, params.merge!(:user => {
                      :name => Faker::Name.name,
                      :email => Faker::Internet.email,
                      :phone => Faker::PhoneNumber.phone_number,
                      :description => Faker::Lorem.sentence(3),
                      :customer => "Sample company",
                      :job_title => "Developer"
                      })
                   
    json_response.should include("success")
    json_response['requester_id'].should be_eql @account.all_contacts.last.id
    
    json_response["success"].should eql(true)
  end

  it "should delete multiple contacts" do
    contact = add_new_user(@account)
    contact_one = add_new_user(@account)
    delete :destroy, params.merge!(:id => "multiple", :ids => [contact.id,contact_one.id])
    @account.all_contacts.find(contact.id).deleted.should be true
    @account.all_contacts.find(contact_one.id).deleted.should be true
  end

  it "should restore multiple contacts" do
    contact = add_new_user(@account)
    contact.deleted = 1
    contact.save!
    contact_one = add_new_user(@account)
    contact_one.deleted = 1
    contact_one.save!
    put :restore, params.merge!(:id => "multiple", :ids => [contact.id,contact_one.id])
    @account.all_contacts.find(contact.id).deleted.should be false
    @account.all_contacts.find(contact_one.id).deleted.should be false
  end

  # Negative Cases
  
  it "should not create a contact with exisiting email address" do
    contact = add_new_user(@account)
    post :create, params.merge!(:user => {
                      :name => Faker::Name.name,
                      :email => contact.email,
                      :phone => Faker::PhoneNumber.phone_number,
                      :description => Faker::Lorem.sentence(3),
                      :customer => "Sample company",
                      :job_title => "Developer"
                      })
                   
    json_response.should include("error")
    json_response["error"].should be_true
    json_response["message"][0][1].should include("has already been taken")
  end
end
