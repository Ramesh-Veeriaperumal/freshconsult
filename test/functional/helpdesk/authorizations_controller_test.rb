require 'test_helper'

class Helpdesk::AuthorizationsControllerTest < ActionController::TestCase

  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @authorization = Helpdesk::Authorization.last
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

    context "on valid put to update" do
      setup do
        @params = {:role_token => 'writer'}
        put :update, :id => @authorization.id, :helpdesk_authorization => @params
      end
      should_redirect_to "helpdesk_authorizations_url"
      should_assign_to :item, :authorization
      should_set_the_flash_to "The authorization has been updated"
      should_not_change "Helpdesk::Authorization.count"
      should "have updated the authorization" do
        @authorization.reload
        assert_equal @params[:role_token], @authorization.role_token
      end
    end

    context "on invalid put to update" do
      setup do
        @params = {:role_token => 'fail!'}
        put :update, :id => @authorization.id, :helpdesk_authorization => @params
      end
      should_redirect_to back
      should_assign_to :item, :authorization
      should_not_change "Helpdesk::Authorization.count"
      should "not have updated the authorization" do
        @authorization.reload
        assert_not_equal @params[:role_token], @authorization.role_token
      end
    end

    context "on put to update with invalid id" do
      should "respond with not found" do
        assert_raise ActiveRecord::RecordNotFound do
          @params = {:role_token => 'writer'}
          put :update, :id => "fail!", :helpdesk_authorization => @params
        end
      end
    end

    context "on valid post to create" do
      setup do
        @params = {:user_id => 999, :role_token => 'writer'}
        post :create, :helpdesk_authorization => @params
      end
      should_assign_to :item, :authorization
      should_redirect_to "helpdesk_authorizations_url"
      should_set_the_flash_to "The authorization has been created"
      should_change "Helpdesk::Authorization.count", 1
      should "create authorization with @params" do
        authorization = Helpdesk::Authorization.last
        @params.each { |k, v| assert_equal v, authorization.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @params = {:user_id => @user.id, :role_token => 'fail!'}
        post :create, :helpdesk_authorization => @params
      end
      should_assign_to :item, :authorization
      should_not_change "Helpdesk::Authorization.count"
      should_redirect_to back
    end

    context "on valid post to create trying to create duplicate" do
      setup do
        @params = {:user_id => @user.id, :role_token => 'writer'}
        post :create, :helpdesk_authorization => @params
      end
      should_assign_to :item, :authorization
      should_not_change "Helpdesk::Authorization.count"
      should_redirect_to back
    end


    context "on delete to destroy with multiple valid ids" do
      setup do
        @authorizations = Helpdesk::Authorization.all
        delete :destroy, :ids => @authorizations.map { |t| t.to_param }
      end

      should_assign_to :items, :authorizations
      should_redirect_to back

      should "set flash" do
        assert_match(/authorizations were deleted/, flash[:notice])
      end

      should "assign correct authorizations" do
        assert_equal @authorizations, assigns(:authorizations)
      end

      should "have deleted authorizations" do
        @authorizations.each { |t| assert !Helpdesk::Authorization.find_by_id(t.id) }
      end
    end

    context "on delete to destroy with no valid ids" do
      setup do
        delete :destroy, :ids => ['invalid 1', 'invalid 2']
      end

      should_assign_to :items, :authorizations
      should_redirect_to back

      should "set flash" do
        assert_match(/0 authorizations were deleted/, flash[:notice])
      end

      should "assign correct authorizations" do
        assert_equal [], assigns(:authorizations)
      end

      should_not_change "Helpdesk::Authorization.count"
    end

    context "on get to autocomplete" do
      setup do
        get :autocomplete, :v => "n"
      end
      
      should_respond_with :success
      should_respond_with_content_type "application/json"

      should "return correct json response" do
        items = User.find(
          :all, 
          :conditions => ["name like ?", "%n%"], 
          :limit => 30
        )
        correct = {"results" => items.map {|i| {'id' => i.id, 'value' => i.name} } } 
        assert_equal correct, ActiveSupport::JSON.decode(@response.body)
      end

    end

  end


  context "controller's private and protected methods made public" do
    setup { publicize_controller_methods }
    teardown { privatize_controller_methods }

    should "return class_name from Namespace::ClassName" do
      assert_equal "authorization", @controller.cname
    end

    should "return namespace_class_name from Namespace::ClassName" do
      assert_equal "helpdesk_authorization", @controller.nscname
    end

    should "return correct scoper" do
      assert_same Helpdesk::Authorization, @controller.scoper
    end

    should "find when load by param is called" do
      Helpdesk::Authorization.expects(:find_by_id).with(999).returns(:some_value)
      assert_equal :some_value, @controller.load_by_param(999)
    end

    should "fetch item when load_item called" do
      Helpdesk::Authorization.expects(:find_by_id).with(999).returns(:some_value)
      @controller.expects(:params).returns({:id => 999})
      assert_equal :some_value, @controller.load_item
    end

    should "render not found if load_item called with invalid id" do
      Helpdesk::Authorization.expects(:find_by_id).with(999).returns(nil)
      @controller.expects(:params).returns({:id => 999})
      assert_raise ActiveRecord::RecordNotFound do
        @controller.load_item
      end
    end

    should "build a new authorization from params" do
      @controller.expects(:params).returns({'helpdesk_authorization' => {'user_id' => 666, 'role_token' => 'admin'}})
      authorization = @controller.build_item
      assert_equal 666, authorization.user_id
      assert_equal 'admin', authorization.role_token
    end


    should "return correct autocomplete search field" do
      assert_equal "name", @controller.autocomplete_field
    end

    should "return correct autocomplete scoper" do
      assert_same User, @controller.autocomplete_scoper
    end

  end

end
