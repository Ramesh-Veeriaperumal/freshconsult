require 'test_helper'

class Helpdesk::TagsControllerTest < ActionController::TestCase

  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @tag = Helpdesk::Tag.first
    end

    context "on get to :index" do
      setup do
        get :index
      end
      should_assign_to :tags
      should_respond_with :success
      should_render_template :index
      should_not_set_the_flash
    end

    context "on get to show with valid id" do
      setup do
        get :show, :id => @tag.id
      end
      should_assign_to :tag, :tickets
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
        get :edit, :id => @tag.id
      end

      should_respond_with :success
      should_render_template :edit
      should_render_a_form
      should_not_show_form_errors

      should_assign_to :item, :tag
      should "load correct tag" do
        assert_equal @tag, assigns(:tag)
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
        put :update, :id => @tag.id, :helpdesk_tag => @params
      end
      should_redirect_to "helpdesk_tag_url(@tag)";
      should_assign_to :item, :tag
      should_set_the_flash_to "The tag has been updated"
      should_not_change "Helpdesk::Tag.count"
      should "have updated the ticket" do
        @tag.reload
        assert_equal @params[:name], @tag.name
      end
    end

    context "on invalid put to update" do
      setup do
        @params = {:name => ''}
        put :update, :id => @tag.id, :helpdesk_tag => @params
      end
      should_render_template :edit
      should_assign_to :item, :tag
      should_show_form_errors
      should_render_a_form
      should_not_change "Helpdesk::Tag.count"
      should "not have updated the tag" do
        @tag.reload
        assert_not_equal @params[:name], @tag.name
      end
    end
    
    context "without rendering" do 
      setup do
        @controller.stubs(:render)
        @items = mock
      end
      should "Get :index once with each sort field" do
        Helpdesk::Tag::SORT_SQL_BY_KEY.each do |k, s|
          Helpdesk::Tag.expects(:paginate).with(
            :page => '1',
            :order => s,
            :per_page => 30
          )
          get :index, :page => 1, :sort => k
        end
      end
    end

    context "on delete to destroy with multiple valid ids" do
      setup do
        @tags = Helpdesk::Tag.all
        delete :destroy, :ids => @tags.map { |t| t.to_param }
      end

      should_assign_to :items, :tags
      should_redirect_to back

      should "set flash" do
        assert_match(/tags were deleted/, flash[:notice])
      end

      should "assign correct tags" do
        assert_equal @tags, assigns(:tags)
      end

      should "have deleted tags" do
        @tags.each { |t| assert !Helpdesk::Tag.find_by_id(t.id) }
      end
    end

    context "on delete to destroy with no valid ids" do
      setup do
        delete :destroy, :ids => ['invalid 1', 'invalid 2']
      end

      should_assign_to :items, :tags
      should_redirect_to back

      should "set flash" do
        assert_match(/0 tags were deleted/, flash[:notice])
      end

      should "assign correct tags" do
        assert_equal [], assigns(:tags)
      end

      should_not_change "Helpdesk::Tag.count"
    end

    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "tag", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_tag", @controller.nscname
      end

      should "return correct scoper" do
        assert_same Helpdesk::Tag, @controller.scoper
      end

      should "find when load by param is called" do
        Helpdesk::Tag.expects(:find_by_id).with(999).returns(:some_value)
        assert_equal :some_value, @controller.load_by_param(999)
      end

      should "fetch item when load_item called" do
        Helpdesk::Tag.expects(:find_by_id).with(999).returns(:some_value)
        @controller.expects(:params).returns({:id => 999})
        assert_equal :some_value, @controller.load_item
      end

      should "render not found if load_item called with invalid id" do
        Helpdesk::Tag.expects(:find_by_id).with(999).returns(nil)
        @controller.expects(:params).returns({:id => 999})
        assert_raise ActiveRecord::RecordNotFound do
          @controller.load_item
        end
      end

      should "build a new tag from params" do
        @controller.expects(:params).returns({'helpdesk_tag' => {'name' => "bill"}})
        tag = @controller.build_item
        assert_equal "bill", tag.name
      end
    end

  end

end
