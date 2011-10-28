require 'spec_helper'

describe Social::FacebookPagesController do

  #Delete these examples and add some real ones
  it "should use Social::FacebookPagesController" do
    controller.should be_an_instance_of(Social::FacebookPagesController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

  describe "GET 'edit'" do
    it "should be successful" do
      get 'edit'
      response.should be_success
    end
  end
end
