require 'spec_helper'

describe Support::CompanyTicketsController do

  #Delete these examples and add some real ones
  it "should use Support::CompanyTicketsController" do
    controller.should be_an_instance_of(Support::CompanyTicketsController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
end
