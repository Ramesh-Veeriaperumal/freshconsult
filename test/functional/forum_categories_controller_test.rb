require 'test/test_helper'
require "authlogic/test_case"

class ForumCategoriesControllerTest < ActionController::TestCase
  
  def setup
    activate_authlogic
    UserSession.create(User.first)
  end
  
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:forum_categories)
  end

  test "should get new" do
    get :new
    assert_response :success
  end
  
  test "should create forum_category" do
    assert_difference('ForumCategory.count') do
      post :create, :forum_category => {:name => "Freshdesk Forum Category", :description => "Freshdesk Forum Category Description" }#, :user_session => {:login => "sample@freshdesk.com",:password => "test"}
    end
    assert_redirected_to categories_path
  end

  test "should show forum_category" do
    get :show, :id => forum_categories(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => forum_categories(:one).to_param
    assert_response :success
  end

  test "should update forum_category" do
    put :update, :id => forum_categories(:one).to_param, :forum_category => { :name => "Updated Forum Category" }
    assert_redirected_to categories_path
  end

  test "should destroy forum_category" do
    assert_difference('ForumCategory.count', -1) do
      delete :destroy, :id => forum_categories(:one).to_param
    end
   assert_redirected_to categories_path
 end
 
end
