require 'spec_helper'

describe Mobihelp::App do
  before(:all) do 
      @account = create_test_account
      @mobihelp_app = create_mobihelp_app
  end

  it "should have unique app name for each account" do
    dup_mobihelp_app = Factory.build(:mobihelp_app)
    status = dup_mobihelp_app.save
    status.should_not be_true
  end

  it "should require a app name" do
    mh_attr = { :name => " ", :platform => 1, :config => {} }
    test_app = Mobihelp::App.new(mh_attr)
    test_app.should_not be_valid
  end

  it "should reject invalid platform" do
    mh_attr = { :name => " ", :platform => 0, :config => {} }
    test_app = Mobihelp::App.new(mh_attr)
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
