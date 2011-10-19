require 'spec_helper'

describe Admin::ZenImportController do

  #Delete these examples and add some real ones
  it "should use Admin::ZenImportController" do
    controller.should be_an_instance_of(Admin::ZenImportController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
end
