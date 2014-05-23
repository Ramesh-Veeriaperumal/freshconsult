require 'spec_helper'
require 'base64'

describe Mobihelp::DevicesController do
  integrate_views
  setup :activate_authlogic
  self.use_transactional_fixtures = false

  before(:all) do
    @account = create_test_account
    @mobihelp_app = create_mobihelp_app
  end

  before(:each) do
    @request.host = @account.full_domain
    @request.env['HTTP_REFERER'] = 'sessions/new'
    @request.env['X-FD-Mobihelp-Auth'] = get_app_auth_key(@mobihelp_app) 
    @request.params['format'] = "html"
  end

  it "should accept a device registration" do
    post  :register, {
      "user" => {
        "name" => "Mobihelp User",
        "email" => "mobihelp@ff.com",
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
    }, { "X-FD-Mobihelp-Auth" => get_app_auth_key(@mobihelp_app) }
    JSON.parse(response.body)["config"].should_not be_nil
  end

  it "should not allow device registration with blank app id and secret" do
    @request.env['X-FD-Mobihelp-Auth'] = "" 
    post  :register, {
      "user" => {
        "name" => "Mobihelp User",
        "email" => "mobihelp@ff.com",
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
    }, { "X-FD-Mobihelp-Auth" => "" }
    JSON.parse(response.body)["config"].should be_nil
  end

  it "should not allow device registration with invalid app id and secret" do
    @request.env['X-FD-Mobihelp-Auth'] = Base64.encode64("invalid_app_id:invalid_app_secret")
    post  :register, {
      "user" => {
        "name" => "Mobihelp User",
        "email" => "mobihelp@ff.com",
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
    }, { "X-FD-Mobihelp-Auth" => Base64.encode64("invalid_app_id:invalid_app_secret") }
    JSON.parse(response.body)["config"].should be_nil
  end

  it "should accept a user registration" do
    device_id = SecureRandom.hex
    email_id = "mobihelp@ffemail.com"
    post  :register_user, {
      "user" => {
        "name" => "Mobihelp User",
        "email" => email_id,
        "external_id" => device_id
      },
      "device_info" => {
        "device_uuid" => device_id,
        "make"        => "LG" ,
        "model"       => "Nexus 5",
        "os_version"  => "KitKat",
        "app_version" => "2.3.1",
        "sdk_version" => "1.0",
      }
    }, { "X-FD-Mobihelp-Auth" => get_app_auth_key(@mobihelp_app) }

    @account.users.find_by_email(email_id).should be_an_instance_of(User)
    @account.users.find_by_email(email_id).mobihelp_devices.should have(1).items
  end

  it "should accept a user registration without email" do
    device_id = SecureRandom.hex
    post  :register_user, {
      "user" => {
        "name" => "Mobihelp User",
        "external_id" => device_id
      },
      "device_info" => {
        "device_uuid" => device_id,
        "make"        => "LG" ,
        "model"       => "Nexus 5",
        "os_version"  => "KitKat",
        "app_version" => "2.3.1",
        "sdk_version" => "1.0",
      }
    }, { "X-FD-Mobihelp-Auth" => get_app_auth_key(@mobihelp_app) }

    @account.users.find_by_external_id(device_id).should be_an_instance_of(User)
    @account.users.find_by_external_id(device_id).mobihelp_devices.should have(1).items
  end

  it "should accept a user registration for existing user" do
    device_id = SecureRandom.hex
    email_id = User.last.email
    post  :register_user, {
      "user" => {
        "name" => "Mobihelp User",
        "email" => email_id,
        "external_id" => device_id
      },
      "device_info" => {
        "device_uuid" => device_id,
        "make"        => "LG" ,
        "model"       => "Nexus 5",
        "os_version"  => "KitKat",
        "app_version" => "2.3.1",
        "sdk_version" => "1.0",
      }
    }, { "X-FD-Mobihelp-Auth" => get_app_auth_key(@mobihelp_app) }

    @account.users.find_by_external_id(email_id).should be_an_instance_of(User)
    @account.users.find_by_external_id(device_id).mobihelp_devices.find_by_device_uuid(device_id).should be_an_instance_of(Mobihelp::Device);
  end

  it "should provide config for app" do
    device_id = SecureRandom.hex
    email_id = User.last.email

    get  :app_config

    info = JSON.parse(response.body)["config"]
    info["breadcrumb_count"].should_not be_nil
    info["debug_log_count"].should_not be_nil
    info["acc_status"].should_not be_nil
    info.include?("app_review_launch_count").should_not be_false
  end

end