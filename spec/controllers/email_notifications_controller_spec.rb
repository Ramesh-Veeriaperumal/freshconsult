require 'spec_helper'

describe EmailNotificationsController do

  #Delete these examples and add some real ones
  it "should use EmailNotificationsController" do
    controller.should be_an_instance_of(EmailNotificationsController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'update'" do
    it "should be successful" do
      get 'update'
      response.should be_success
    end
  end
end
