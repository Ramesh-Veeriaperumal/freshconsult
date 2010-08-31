require 'test_helper'

class Helpdesk::DashboardControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on get index" do
      setup do
        get :index
      end
      should_assign_to :items
      should_respond_with :success
      should_render_template :index
    end

    context "without rendering" do 
      setup do
        @controller.stubs(:render)
        @items = mock
      end
    end
  end
end
