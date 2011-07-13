require 'spec_helper'

describe Admin::TwitterController do

  #Delete these examples and add some real ones
  it "should use Admin::TwitterController" do
    controller.should be_an_instance_of(Admin::TwitterController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
end
