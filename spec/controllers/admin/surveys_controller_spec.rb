require 'spec_helper'

describe Admin::SurveysController do

  #Delete these examples and add some real ones
  it "should use Admin::SurveysController" do
    controller.should be_an_instance_of(Admin::SurveysController)
  end


  describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end
end
