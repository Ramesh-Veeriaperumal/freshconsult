require 'test_helper'

class Helpdesk::GuidesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @guide = Helpdesk::Guide.first
    end

    context "on get to :index" do
      setup do
        get :index
      end
      should_assign_to :items
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash
    end

    context "on get to new" do
      setup do
        get :new
      end
      should_assign_to :item, :guide
      should_respond_with :success
      should_render_template :new
      should_not_set_the_flash
      should_render_a_form
      should_not_show_form_errors
    end

    context "on get to show with valid id" do
      setup do
        get :show, :id => @guide.id
      end
      should_assign_to :guide, :articles
      should_respond_with :success
      should_render_template :show
      should_not_set_the_flash
    end
    
    context "on get to show with invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          get :show, :id => "invalid id"
        end
      end
    end

    context "on get edit with valid id" do
      setup do
        get :edit, :id => @guide.id
      end

      should_respond_with :success
      should_render_template :edit
      should_render_a_form
      should_not_show_form_errors

      should_assign_to :item, :guide
      should "load correct guide" do
        assert_equal @guide, assigns(:guide)
      end
    end

    context "on get edit with invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          get :edit, :id => "invalid id"
        end
      end
    end

    context "on valid put to update" do
      setup do
        @params = {:name => 'new name'}
        put :update, :id => @guide.id, :helpdesk_guide => @params
      end
      should_redirect_to "helpdesk_guide_url(@guide)";
      should_assign_to :item, :guide
      should_set_the_flash_to "The guide has been updated"
      should_not_change "Helpdesk::Guide.count"
      should "have updated the ticket" do
        @guide.reload
        assert_equal @params[:name], @guide.name
      end
    end

    context "on valid put to update with save_and_create specified" do
      setup do
        @params = {:name => 'new name'}
        put :update, :id => @guide.id, :helpdesk_guide => @params, :save_and_create => true
      end
      should_redirect_to "new_helpdesk_guide_url";
      should_assign_to :item, :guide
      should_set_the_flash_to "The guide has been updated"
      should_not_change "Helpdesk::Guide.count"
      should "have updated the ticket" do
        @guide.reload
        assert_equal @params[:name], @guide.name
      end
    end

    context "on invalid put to update" do
      setup do
        @params = {:name => ''}
        put :update, :id => @guide.id, :helpdesk_guide => @params
      end
      should_render_template :edit
      should_assign_to :item, :guide
      should_show_form_errors
      should_render_a_form
      should_not_change "Helpdesk::Guide.count"
      should "not have updated the guide" do
        @guide.reload
        assert_not_equal @params[:name], @guide.name
      end
    end

    context "on valid post to create" do
      setup do
        @params = {:name => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_guide => @params
      end
      should_assign_to :item, :guide
      should_redirect_to "helpdesk_guide_url(@item)"
      should_set_the_flash_to "The guide has been created"
      should_change "Helpdesk::Guide.count", 1
      should "create guide with @params" do
        guide = Helpdesk::Guide.last
        @params.each { |k, v| assert_equal v, guide.send(k) }
      end
    end

    context "on valid post to create with save_and_create specified" do
      setup do
        @params = {:name => 'Billy Jean', :description => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_guide => @params, :save_and_create => true
      end
      should_assign_to :item, :guide
      should_redirect_to "new_helpdesk_guide_url"
      should_set_the_flash_to "The guide has been created"
      should_change "Helpdesk::Guide.count", 1
      should "create guide with @params" do
        guide = Helpdesk::Guide.last
        @params.each { |k, v| assert_equal v, guide.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @params = {:name => '', :description => "She's just a girl who thinks I am the one"}
        post :create, :helpdesk_guide => @params
      end
      should_assign_to :item, :guide
      should_not_change "Helpdesk::Guide.count"
      should_render_a_form
      should_render_template :new
      should_show_form_errors
    end

    context "on privatize valid id" do
      setup do
        @guide.update_attribute(:hidden, false)
        put :privatize, :id => @guide.id
      end
      should_assign_to :guide, :item
      should_redirect_to back
      should_set_the_flash_to "The guide was made private"
      should "set guide.hidden to true" do
        @guide.reload
        assert @guide.hidden
      end
    end

    context "on privatize invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          put :privatize, :id => "not a valid id"
        end
      end
    end

    context "on publicize valid id" do
      setup do
        @guide.update_attribute(:hidden, true)
        put :publicize, :id => @guide.id
      end
      should_assign_to :guide, :item
      should_redirect_to back
      should_set_the_flash_to "The guide was made public"
      should "set guide.hidden to false" do
        @guide.reload
        assert !@guide.hidden
      end
    end

    context "on publicize invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          put :publicize, :id => "not a valid id"
        end
      end
    end

    context "on put to reorder" do
      setup do
        items = Helpdesk::Guide.find(:all, :order => "id desc")
        ids = items.map { |i| i.id }
        put :reorder, :order => ids.join(',')
      end

      should_redirect_to "helpdesk_guides_path"

      should "order guides" do
        items = Helpdesk::Guide.find(:all, :order => "id desc")
        items.each_with_index do |item, i|
          assert_equal i, item.position
        end

      end
    end

    context "on put to reorder_articles" do
      setup do
        @guide = Helpdesk::Guide.first
        @guide.articles.clear
        Helpdesk::Article.all.each { |a| @guide.articles << a }
        
        ids = @guide.articles.find(:all, :order => "id desc").map { |a| a.id }
        put :reorder_articles, :id => @guide.id, :order => ids.join(',')
      end

      should_redirect_to "helpdesk_guide_path(@item)"

      should "order guides" do
        @guide.articles.find(:all, :order => "id desc").each_with_index do |item, i|
          r = item.article_guides.find_by_guide_id_and_article_id(@guide.id, item.id)
          assert_equal i, r.position
        end
      end
    end
  end

  context "controller's private and protected methods made public" do
    setup { publicize_controller_methods }
    teardown { privatize_controller_methods }

    should "return class_name from Namespace::ClassName" do
      assert_equal "guide", @controller.cname
    end

    should "return namespace_class_name from Namespace::ClassName" do
      assert_equal "helpdesk_guide", @controller.nscname
    end

    should "return correct scoper" do
      assert_same Helpdesk::Guide, @controller.scoper
    end

    should "find_by_id when load by param is called" do
      Helpdesk::Guide.expects(:find_by_id).with(999).returns(:some_value)
      assert_equal :some_value, @controller.load_by_param(999)
    end

    should "fetch item when load_item called" do
      Helpdesk::Guide.expects(:find_by_id).with(999).returns(:some_value)
      @controller.expects(:params).returns({:id => 999})
      assert_equal :some_value, @controller.load_item
    end

    should "render not found if load_item called with invalid id" do
      Helpdesk::Guide.expects(:find_by_id).with(999).returns(nil)
      @controller.expects(:params).returns({:id => 999})
      assert_raise ActiveRecord::RecordNotFound do
        @controller.load_item
      end
    end

    should "build a new guide from params" do
      @controller.expects(:params).returns({'helpdesk_guide' => {'name' => "bill"}})
      guide = @controller.build_item
      assert_equal "bill", guide.name
    end


  end

end
