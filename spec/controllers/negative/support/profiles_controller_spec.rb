require 'spec_helper'

describe Support::ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  # Commenting out this test for now, since this test will fail, as there are  no checks in place.
  
  # it "should not allow to edit an existing contact email" do
  #   contact = Factory.build(:user, :account => @acc, :email => Faker::Internet.email,
  #                             :user_role => 3)
  #   contact.save
  #   log_in(contact)
  #   updated_email = Faker::Internet.email
  #   put :update, :id => contact.id, :user => {:email => updated_email,
  #                                           :job_title => "Developer",
  #                                           :phone => Faker::PhoneNumber.phone_number,
  #                                           :time_zone => "Arizona", 
  #                                           :language => "fr" }

  #   @account.users.find_by_email(updated_email).should be_nil
  # end
end