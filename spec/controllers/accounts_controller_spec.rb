require 'spec_helper'

describe AccountsController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:each) do
    @account.reload
    @account.make_current
    login_admin
  end

  it 'should signup a new account' do
    admin_email = Faker::Internet.email; admin_name = Faker::Name.name
    signup_params = { "callback"=>"", "account"=>{"name"=>"RSpec Test", "domain"=>"rspectest"}, 
      "utc_offset"=>"5.5", "user"=>{"email"=>admin_email, "name"=>admin_name} }
    
    Resque.inline = true 
    Billing::Subscription.any_instance.stubs(:create_subscription).returns(true)
    post :new_signup_free, signup_params
    Resque.inline = false
    Billing::Subscription.any_instance.unstub(:create_subscription)
    
    response.should be_success
    signup_status = JSON.parse(response.body)
    signup_status["success"].should be_true
    signup_status["url"].should match(/http:\/\/rspectest.freshpo.com\/signup_complete/)

    new_account = Account.find(signup_status["account_id"])
    new_account.admin_email.should match(admin_email)
  end

  it 'should get account data on edit without redis_display_id feature' do
    get :edit
    @account.features.redis_display_id.destroy
    assigns[:supported_languages_list].should be_eql(@account.account_additional_settings.supported_languages)
    assigns[:ticket_display_id].should be_eql(@account.get_max_display_id)
  end

  it 'should get updated ticket display id with redis_display_id feature' do
    @account.features.redis_display_id.create
    controller.remove_key "TICKET_DISPLAY_ID:#{@account.id}"
    Account.any_instance.stubs(:get_max_display_id).returns(0)
    new_display_id = (10000..1000000).to_a.sample
    @account.update_attributes(:ticket_display_id => new_display_id)
    
    get :edit
    assigns[:ticket_display_id].should be_eql(new_display_id - 1)

    @account.features.redis_display_id.destroy
  end  

  it 'should update account details' do
    update_params = {"account"=>{"main_portal_attributes"=>{"name"=>"RSpec new account", 
      "portal_url"=>"", "language"=>"en", "preferences"=>{"logo_link"=>"", "header_color"=>"#252525", 
        "tab_color"=>"#006063", "bg_color"=>"#efefef", "contact_info"=>""}, "id"=>"1"}, 
        "account_additional_settings_attributes"=>{"date_format"=>"1", "id"=>"1"}, 
        "time_zone"=>"Chennai", "ticket_display_id"=>"100"}, "redirect_url"=>""}
    put :update, update_params
    @account.reload
    @account.main_portal.name.should match("RSpec new account")
  end

  it 'should delete main portal logo' do
    @account.main_portal.build_logo(:content => fixture_file_upload('files/image.gif', 'image/gif', :binary), 
     :description => "logo", 
     :account_id => @account.id).save

    delete :delete_logo
    @account.reload
    @account.main_portal.logo.should be_blank
  end

  it 'should delete main portal favicon' do
    @account.main_portal.build_fav_icon(:content => fixture_file_upload('files/image.gif', 'image/gif', :binary), 
     :description => "fav_icon", 
     :account_id => @account.id).save

    delete :delete_favicon
    @account.reload
    @account.main_portal.fav_icon.should be_blank
  end

  describe "POD Info test" do

    it 'should signup a new account for a specific domain to the correct POD info' do
      current_pod_info = PodConfig['CURRENT_POD']
      PodConfig['CURRENT_POD'] = "eu"

      admin_email = Faker::Internet.email; admin_name = Faker::Name.name
      create_new_test_account("RSpec Test2", "rspectest2", admin_email, admin_name)
      
      response.should be_success
      signup_status = JSON.parse(response.body)
      signup_status["success"].should be_true
      signup_status["url"].should match(/http:\/\/rspectest2.freshpo.com\/signup_complete/)

      new_account = Account.find(signup_status["account_id"])
      shard_mapping = ShardMapping.fetch_by_account_id(new_account.id)
      shard_mapping.pod_info.should match("eu")
      new_account.admin_email.should match(admin_email)

      #reset the POD_INFO
      PodConfig['CURRENT_POD'] = current_pod_info
    end

    it 'should signup a new account for a specific subdomain to the correct POD info' do
      current_pod_info = PodConfig['CURRENT_POD']
      PodConfig['CURRENT_POD'] = "us-east-custom"

      admin_email = Faker::Internet.email; admin_name = Faker::Name.name
      create_new_test_account("Test Custom", "testcustom", admin_email, admin_name)
      
      response.should be_success
      signup_status = JSON.parse(response.body)
      signup_status["success"].should be_true
      signup_status["url"].should match(/http:\/\/testcustom.freshpo.com\/signup_complete/)

      new_account = Account.find(signup_status["account_id"])
      shard_mapping = ShardMapping.fetch_by_account_id(new_account.id)
      shard_mapping.pod_info.should match("us-east-custom")
      new_account.admin_email.should match(admin_email)

      #reset the POD_INFO
      PodConfig['CURRENT_POD'] = current_pod_info
    end
  end 
end