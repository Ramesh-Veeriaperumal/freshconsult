require 'spec_helper'

describe Support::ProfilesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before do
    @account = create_test_account
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    @user = @account.users.find_by_email("customer@customer.in")
    log_in(@user)
  end

  it "should edit an existing contact" do
    get :edit, :id => @user.id
    response.should render_template :edit
    phone_no = Faker::PhoneNumber.phone_number
    put :update, :id => @user.id, :user => {:email => @user.email,
                                            :job_title => "Developer",
                                            :phone => phone_no,
                                            :time_zone => "Arizona", 
                                            :language => "fr" }
    edited_customer = @account.users.find_by_email("customer@customer.in")
    edited_customer.phone.should be_eql(phone_no)
    edited_customer.time_zone.should be_eql("Arizona")
    edited_customer.language.should be_eql("fr")
  end
end