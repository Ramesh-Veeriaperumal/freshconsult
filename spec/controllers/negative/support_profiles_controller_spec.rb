require 'spec_helper'

describe Support::ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before do
    @account = create_test_account
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
  end

  it "should not allow to edit an existing contact email" do
    contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
                              :user_role => 3)
    contact.save
    log_in(contact)
    updated_email = Faker::Internet.email
    put :update, :id => contact.id, :user => {:email => updated_email,
                                            :job_title => "Developer",
                                            :phone => Faker::PhoneNumber.phone_number,
                                            :time_zone => "Arizona", 
                                            :language => "fr" }

    # This test will fail. No check in place.
    @account.users.find_by_email(updated_email).should be_nil
  end
end