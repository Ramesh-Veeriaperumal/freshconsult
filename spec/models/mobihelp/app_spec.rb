require 'spec_helper'

describe Mobihelp::App do
  before(:all) do 
      @mobihelp_app = create_mobihelp_app
  end

  it "should have unique app name for each account" do
    test_app = FactoryGirl.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app.save
    dup_test_app = FactoryGirl.build(:mobihelp_app, :name =>  test_app.name)
    
    dup_test_app.should be_valid
  end

  it "should allow to add an app with the same name of deleted app" do
    dup_mobihelp_app = @mobihelp_app.dup
    @mobihelp_app.deleted = true
    @mobihelp_app.save
    status = dup_mobihelp_app.save
    
    status.should be true

    Mobihelp::App.find_by_id(dup_mobihelp_app).destroy
    @mobihelp_app.deleted = false
    @mobihelp_app.save
  end

  it "should get updated if the app name is already exist" do
    test_app = FactoryGirl.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app1 = FactoryGirl.build(:mobihelp_app, :name => "Fresh#{Time.now}#{Time.now.nsec}")
    test_app.save
    test_app1.save
    test_app1.name = test_app.name;

    status = test_app1.save

    status.should be true
  end

  it "should require a app name" do
    test_app = FactoryGirl.build(:mobihelp_app, :name => " ")
    test_app.should_not be_valid
  end

  it "should reject invalid platform" do
    test_app = FactoryGirl.build(:mobihelp_app, :platform => 0)
    test_app.should_not be_valid
  end

end
