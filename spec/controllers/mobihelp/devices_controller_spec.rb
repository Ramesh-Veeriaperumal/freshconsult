require 'spec_helper'
require 'base64'

describe Mobihelp::DevicesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    #@account = create_test_account
    @mobihelp_app = create_mobihelp_app
  end

  before(:each) do
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(@mobihelp_app) 
    @request.params['format'] = "html"
    @device_attr = {
      "user" => {
        "name" => "Mobihelp User",
        "email" => Faker::Internet.email,
        "external_id" => "device_id_uu_id"
      },
      "device_info" => {
        "device_uuid" => "mobihelp_dev_1231312312a",
        "make"        => "LG" ,
        "model"       => "Nexus 5",
        "os_version"  => "KitKat",
        "app_version" => "2.3.1",
        "sdk_version" => "1.0",
      }
    }
  end

  it "should accept a device registration" do
    post  :register, @device_attr
    JSON.parse(response.body)["config"].should_not be_nil
  end

  it "should not allow device registration with blank app id and secret" do
    @request.env['X-FD-Mobihelp-Auth'] = "" 
    post  :register, @device_attr
    JSON.parse(response.body)["config"].should be_nil
  end

  it "should not allow device registration with invalid app id and secret" do
    @request.env['X-FD-Mobihelp-Auth'] = Base64.encode64("invalid_app_id:invalid_app_secret")
    post  :register, @device_attr
    JSON.parse(response.body)["config"].should be_nil
  end

  it "should accept a user registration" do
    device_id = SecureRandom.hex
    email_id = Faker::Internet.email
    @device_attr["user"].merge!("email" => email_id)
    @device_attr["user"].merge!("external_id" => device_id)
    @device_attr["device_info"].merge!("device_uuid" => device_id)
    post  :register_user, @device_attr

    @account.users.find_by_email(email_id).should be_an_instance_of(User)
    @account.users.find_by_email(email_id).mobihelp_devices.should have(1).items
  end

  it "should accept a user registration without email" do
    device_id = SecureRandom.hex
    @device_attr["user"].delete("email")
    @device_attr["user"].merge!("external_id" => device_id)
    @device_attr["device_info"].merge!("device_uuid" => device_id)

    post  :register_user, @device_attr

    @account.users.find_by_external_id(device_id).should be_an_instance_of(User)
    @account.users.find_by_external_id(device_id).mobihelp_devices.should have(1).items
  end

  it "should accept a user registration for existing user" do
    device_id = SecureRandom.hex
    email_id = User.last.email
    @device_attr["user"].merge!("email" => email_id)
    @device_attr["user"].merge!("external_id" => device_id)
    @device_attr["device_info"].merge!("device_uuid" => device_id)

    post  :register_user, @device_attr

    @account.users.find_by_external_id(email_id).should be_an_instance_of(User)
    @account.users.find_by_external_id(device_id).mobihelp_devices.find_by_device_uuid(device_id).should be_an_instance_of(Mobihelp::Device);
  end

  it "should not accept a user registration of a deleted app" do
    device_id = SecureRandom.hex
    email_id = User.last.email
    @device_attr["user"].merge!("email" => email_id)
    @device_attr["user"].merge!("external_id" => device_id)
    @device_attr["device_info"].merge!("device_uuid" => device_id)

    @mobihelp_app.deleted = true
    @mobihelp_app.save

    post  :register_user, @device_attr

    @mobihelp_app.deleted = false
    @mobihelp_app.save
    JSON.parse(response.body)["status_code"].should be_eql(30)

    @mobihelp_app.deleted = false
    @mobihelp_app.save
  end

  it "should provide config for app" do
    device_id = SecureRandom.hex
    email_id = User.last.email

    get  :app_config, { "X-FD-Mobihelp-Auth" => get_app_auth_key(@mobihelp_app) }

    info = JSON.parse(response.body)["config"]
    info["breadcrumb_count"].should_not be_nil
    info["debug_log_count"].should_not be_nil
    info["acc_status"].should_not be_nil
    info.include?("app_review_launch_count").should_not be_false
  end

  it "should return error code if the device uuid is not unique" do
    device_id = Mobihelp::Device.last.device_uuid
    @device_attr["device_info"].merge!("device_uuid" => device_id)

    post  :register, @device_attr
    JSON.parse(response.body)["status_code"].should be_eql(40)
  end

end