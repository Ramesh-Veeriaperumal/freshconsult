require 'spec_helper'

describe ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    log_in(@agent)
  end

  after(:all) do
    Delayed::Job.destroy_all
  end

  it "should update mobile and phone number" do
    new_phone  = Faker::PhoneNumber.phone_number
    new_mobile = Faker::PhoneNumber.phone_number
    put :update, :id => @agent.id,
      :agent =>{ :signature_html=>"<p><br></p>\r\n",
        :user_id => "#{@agent.id}" },
        :user =>{ :name => "#{@agent.name}",
        :job_title => "",
        :phone => new_phone,
        :mobile => new_mobile,
        :time_zone => "Chennai",
        :language => "en"
      }
    @agent.reload
    @agent.phone.should be_eql(new_phone)
    @agent.mobile.should be_eql(new_mobile)
    Delayed::Job.last.handler.should include("Your Phone number and Mobile number in #{@account.name} has been updated")
  end

  it "should change api_key" do
    api_before_change = @agent.single_access_token
    post :reset_api_key, {}
    user = User.find_by_id(@agent.id)
    api_after_change = user.single_access_token
    api_after_change.should_not be_eql(api_before_change)
    Delayed::Job.last.handler.should include("Your API key in #{@account.name} has been updated")
  end

  it "should change password" do
    @agent.password = "test"
    @agent.password_confirmation = "test"
    @agent.save
    @agent.reload
    password_before_update = @agent.crypted_password
    post :change_password, {"user_id"=>"#{@agent.id}",
      "user"=>{"current_password"=>"test",
      "password"=>"test1234",
      "password_confirmation"=>"test1234"}
      }
    @agent.reload
    user = User.find_by_id(@agent.id)
    password_after_update = user.crypted_password
    password_before_update.should_not be_eql(password_after_update)
    Delayed::Job.last.handler.should include("Your Password in #{@account.name} has been updated")
  end

  it "should go to the edit page" do
    @agent.reload
    log_in(@agent)
    get :edit, :id => @agent.id
    response.should render_template "profiles/edit.html.erb"
  end

  it "should update notification timesstamp" do
    old_time_stamp = @agent.agent.notification_timestamp
    put :notification_read
    @agent.reload
    @agent.agent.notification_timestamp.should_not be_eql(old_time_stamp)
  end

end
