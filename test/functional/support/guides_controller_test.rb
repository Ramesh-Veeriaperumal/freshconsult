require 'test_helper'

class Support::GuidesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on get to :index" do
      setup do
        get :index
      end

      should_render_with_layout 'default'
      should_assign_to :guides
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash

      should "load correct records" do
        assert_equal Helpdesk::Guide.visible.display_order, assigns(:guides)
      end
    end

    context "on get to show with valid id" do
      setup do
        @guide = Helpdesk::Guide.first
        get :show, :id => @guide.id
      end

      should_render_with_layout 'default'
      should_assign_to :guide
      should_respond_with :success
      should_render_template :show
      should_not_set_the_flash

      should "load correct record" do
        assert_equal @guide, assigns(:guide)
      end

    end
  end
end
