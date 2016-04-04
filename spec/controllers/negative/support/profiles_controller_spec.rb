require 'spec_helper'

describe Support::ProfilesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  it "should not allow to edit an existing contact email" do
    email = Faker::Internet.email
    contact = FactoryGirl.build(:user, :account => @acc, :email => email,
                              :user_role => 3)
    contact.save
    company = FactoryGirl.build(:company)
    company.save
    log_in(contact)
    updated_email = Faker::Internet.email
    put :update, :id => contact.id, :user => {:email => updated_email,
                                            :customer_id => company.id,
                                            :client_manager => true,
                                            :helpdesk_agent => true,
                                            :role_ids => ["1"],
                                            :job_title => "Developer",
                                            :phone => Faker::PhoneNumber.phone_number,
                                            :time_zone => "Arizona", 
                                            :language => "fr" }

    @account.users.find_by_email(updated_email).should be_nil
    user = @account.users.find_by_email(email)
    user.is_client_manager?.should be_falsey
    user.helpdesk_agent.should be_falsey
    user.user_role.should be_eql(3)
  end
end