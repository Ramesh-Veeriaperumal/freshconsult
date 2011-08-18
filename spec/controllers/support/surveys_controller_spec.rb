require 'spec_helper'

describe Support::SurveysController do

  #Delete these examples and add some real ones
  it "should use Support::SurveysController" do
    controller.should be_an_instance_of(Support::SurveysController)
  end


  describe "GET 'new'" do
    it "should be successful" do
      get 'new'
      response.should be_success
    end
  end
end
