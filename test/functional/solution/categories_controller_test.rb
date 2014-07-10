require 'test/test_helper'
require "authlogic/test_case"

class Solution::CategoriesControllerTest < ActionController::TestCase

   
  def setup
    activate_authlogic
    UserSession.create(Factory.create(:admin))
    controller.request.host = 'localhost'
  end
  
  def destroy_session
    @current_user_session = UserSession.find
    @current_user_session.destroy
  end
  
   test "should get index" do
     get :index
     assert_response :success
     assert_not_nil assigns(:categories)
   end

   test "should get new" do
     get :new
     assert_response :success
   end

   test "should not get new" do
     destroy_session
     get :new
     assert_response :redirect
     assert_redirected_to login_url
   end

  test "should create category" do
   assert_difference "Solution::Category.count" do
    post :create, :solution_category =>  Factory.attributes_for(:default_category)
   end
   assert_response :redirect
   assert_redirected_to solution_categories_url
  end
  
  test "should edit category" do
   default_category = Factory.create(:default_category)
   put :update, :id => default_category.id, :solution_category =>  {:name => Forgery(:lorem_ipsum).words(12)}
   assert_response :redirect
   assert_redirected_to solution_categories_url
  end
  
  test "should get edit" do
    default_category = Factory.create(:default_category)
    get :edit, :id =>  default_category.id
    assert_response :redirect
  end
  
  test "should not get edit" do
    default_category = Factory.create(:default_category)
    destroy_session
    get :edit, :id => default_category.id
    assert_response :redirect
    assert_redirected_to login_url
  end


end
