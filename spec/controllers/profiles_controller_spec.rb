require 'spec_helper'

describe ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @user = add_test_agent(@account)
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_7_5) AppleWebKit/537.36 
                                        (KHTML, like Gecko) Chrome/32.0.1700.107 Safari/537.36"
    log_in(@user)
    # Delayed::Job.destroy_all
  end

  it "should update mobile and phone number" do
    put :update, :id => @user.id, 
      :agent =>{ :signature_html=>"<p><br></p>\r\n", 
        :user_id => "#{@user.id}" },
      :user =>{ :name => "#{@user.name}", 
        :job_title => "", 
        :phone => Faker::PhoneNumber.phone_number, 
        :mobile => Faker::PhoneNumber.phone_number, 
        :time_zone => "Chennai", 
        :language => "en"
      }
    # Delayed::Job.last.handler.should include("Your Phone number and Mobile number in #{@account.name} has been updated")
  end

  it "should change api_key" do
    api_before_change = @user.single_access_token
    post :reset_api_key, {}
    user = User.find_by_id(@user.id)
    api_after_change = user.single_access_token
    api_after_change.should_not be_eql(api_before_change)
    # Delayed::Job.last.handler.should include("Your API key in #{@account.name} has been updated")
  end

  it "should change password" do
    password_before_update = @user.crypted_password
    post :change_password, {"user_id"=>"#{@user.id}", 
      "user"=>{"current_password"=>"test", 
      "password"=>"test1", 
      "password_confirmation"=>"test1"}
      }
    user = User.find_by_id(@user.id)
    password_after_update = user.crypted_password
    password_before_update.should_not be_eql(password_after_update)
    # Delayed::Job.last.handler.should include("Your Password in #{@account.name} has been updated")
  end

end
