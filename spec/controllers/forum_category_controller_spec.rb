require 'spec_helper'

describe ForumCategoryController do

  #Delete this example and add some real ones
  it "should use ForumCategoryController" do
    controller.should be_an_instance_of(ForumCategoryController)
  end
  
   describe "GET 'index'" do
    it "should be successful" do
      get 'index'
      response.should be_success
    end
  end

end
