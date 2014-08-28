require 'spec_helper'

describe Support::ProfilesController do
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @user = add_new_user(@account, {:active => true})
  end

  before(:each) do
    log_in(@user)
    #stub_s3_writes
  end

  it "should edit an existing contact" do
    get :edit, :id => @user.id
    response.should render_template :edit
    phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => @user.id, :user => {:name => @user.name,
                                            :job_title => "Developer",
                                            :phone => phone_no,
                                            :time_zone => "Arizona",
                                            :language => "fr" }
    edited_customer = RSpec.configuration.account.user_emails.user_for_email(@user.email)
    edited_customer.phone.should be_eql(phone_no)
    edited_customer.time_zone.should be_eql("Arizona")
    edited_customer.language.should be_eql("fr")
  end

  xit "should delete user avatar" do#profiles_controller_spec.rb
    get :edit, :id => @user.id
    put :update, :id => @user.id, :user => {:avatar_attributes => {:content => fixture_file_upload('files/image33kb.jpg', 'image/jpg', :binary )},
                                            :name => @user.name,
                                            :job_title => @user.job_title,
                                            :phone => @user.phone,
                                            :time_zone => @user.time_zone,
                                            :language => @user.language }
    @user.reload
    @user.avatar.should_not be_nil
    delete :delete_avatar
    @user.reload
    @user.avatar.should be_nil
  end
end
