require 'test/test_helper'
require "authlogic/test_case"

class Solution::ArticlesControllerTest < ActionController::TestCase

   
  def setup
    activate_authlogic
    UserSession.create(Factory.create(:admin))
    controller.request.host = 'localhost'
    Factory.create(:article)
  end
  
  def destroy_session
    @current_user_session = UserSession.find
    @current_user_session.destroy
  end

  test "should create category" do
   assert_difference "Solution::Article.count" do
    post :create, :solution_article =>  {:name => }
   assert_response :redirect
  end
  
end
