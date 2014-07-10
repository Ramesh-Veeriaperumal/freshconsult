require 'spec_helper'

describe Mobihelp::App do
  before(:all) do 
      @mobihelp_app = create_mobihelp_app
  end

  it "should have unique app name for each account" do
    test_app = Factory.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app.save
    dup_test_app = Factory.build(:mobihelp_app, :name =>  test_app.name)
    
    dup_test_app.should be_valid
  end

  it "should allow to add an app with the same name of deleted app" do
    dup_mobihelp_app = @mobihelp_app.clone
    @mobihelp_app.deleted = true
    @mobihelp_app.save
    status = dup_mobihelp_app.save
    
    status.should be_true

    Mobihelp::App.find_by_id(dup_mobihelp_app).destroy
    @mobihelp_app.deleted = false
    @mobihelp_app.save
  end

  it "should get updated if the app name is already exist" do
    test_app = Factory.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app1 = Factory.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app.save
    test_app1.save
    test_app1.name = test_app.name;

    status = test_app1.save

    status.should be_true
  end

  it "should require a app name" do
    test_app = Factory.build(:mobihelp_app, :name => " ")
    test_app.should_not be_valid
  end

  it "should reject invalid platform" do
    test_app = Factory.build(:mobihelp_app, :platform => 0)
    test_app.should_not be_valid
  end

  it "should have a valid bread crumbs count" do
    bread_crumbs_count = @mobihelp_app.config[:bread_crumbs]
    invalid_count = (Mobihelp::App::CONFIGURATIONS[:bread_crumbs][0].to_i - 1).to_s
    @mobihelp_app.config[:bread_crumbs] = invalid_count
    status = @mobihelp_app.save

    @account.mobihelp_apps.find_by_id(@mobihelp_app).config[:bread_crumbs].should be_eql(bread_crumbs_count)
    status.should_not be_true
  end

  it "should have a valid debug log count" do
    debug_log_count = @mobihelp_app.config[:debug_log_count]
    invalid_count = (Mobihelp::App::CONFIGURATIONS[:debug_log_count][0].to_i - 1).to_s
    @mobihelp_app.config[:bread_crumbs] = Mobihelp::App::CONFIGURATIONS[:bread_crumbs][0]
    @mobihelp_app.config[:debug_log_count] = invalid_count
    status = @mobihelp_app.save
    @account.mobihelp_apps.find_by_id(@mobihelp_app).config[:debug_log_count].should be_eql(debug_log_count)
    status.should_not be_true
  end

end
