require 'spec_helper'

describe HomeController do
  
  describe "GET 'index'" do
    it "should redirect to end user portal " do
      get 'index'
      response.should redirect_to(support_guides_path)
    end
  end
end
