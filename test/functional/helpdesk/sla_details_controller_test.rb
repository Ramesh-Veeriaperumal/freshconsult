require 'test_helper'

class Helpdesk::SlaDetailsControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:helpdesk_sla_details)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sla_detail" do
    assert_difference('Helpdesk::SlaDetail.count') do
      post :create, :sla_detail => { }
    end

    assert_redirected_to sla_detail_path(assigns(:sla_detail))
  end

  test "should show sla_detail" do
    get :show, :id => helpdesk_sla_details(:one).to_param
    assert_response :success
  end

  test "should get edit" do
    get :edit, :id => helpdesk_sla_details(:one).to_param
    assert_response :success
  end

  test "should update sla_detail" do
    put :update, :id => helpdesk_sla_details(:one).to_param, :sla_detail => { }
    assert_redirected_to sla_detail_path(assigns(:sla_detail))
  end

  test "should destroy sla_detail" do
    assert_difference('Helpdesk::SlaDetail.count', -1) do
      delete :destroy, :id => helpdesk_sla_details(:one).to_param
    end

    assert_redirected_to helpdesk_sla_details_path
  end
end
