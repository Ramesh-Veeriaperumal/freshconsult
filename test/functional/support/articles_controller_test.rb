require 'test_helper'

class Support::ArticlesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on get to :index" do
      setup do
        get :index, :v => "in"
      end
      should_render_with_layout 'default'
      should_assign_to :articles
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash

      should "load correct records" do
        articles = Helpdesk::Article.visible.find(
          :all, 
          :conditions => ["title LIKE ?", "%in%"],
          :limit => 10
        )
        assert_equal articles, assigns(:articles)
      end

    end
  end
end
