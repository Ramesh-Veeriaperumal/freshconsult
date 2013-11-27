require File.expand_path("#{File.dirname(__FILE__)}/../../spec_helper")

describe Social::FacebookPagesController do
  # integrate_views
  #Delete these examples and add some real ones
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
