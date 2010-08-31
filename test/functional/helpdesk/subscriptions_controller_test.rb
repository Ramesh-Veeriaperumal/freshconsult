require 'test_helper'

class Helpdesk::SubscriptionsControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
      @ticket = Helpdesk::Ticket.first
      @ticket.subscriptions.clear
      @user.subscriptions.clear
    end

    context "on valid post to create" do
      setup do
        post :create, :ticket_id => @ticket.to_param      
      end
      should_redirect_to back
      should_assign_to :item, :subscription
      should_set_the_flash_to "The subscription has been created"
      should_change "Helpdesk::Subscription.count", 1
      should "have created the subscription" do
        subscription = Helpdesk::Subscription.last
        assert_equal @user, subscription.user
        assert_equal @ticket, subscription.ticket
      end
    end

    context "on post to create, attempting to make duplicate subscription" do
      setup do
        @subscription = Helpdesk::Subscription.create(:user => @user, :ticket => @ticket)
        post :create, :ticket_id => @ticket.to_param      
      end
      should_redirect_to back
      should_assign_to :item, :subscription
      should_not_set_the_flash

      # we create 1 subscription in setup, so change = 1 means 
      # post did not create a subscription
      should_change "Helpdesk::Subscription.count", 1
      should "not have created the subscription" do
        assert_equal 1, Helpdesk::Subscription.find_all_by_ticket_id_and_user_id(@ticket.id, @user.id).size
      end
    end

    context "on invalid post to create" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          post :create, :ticket_id => "not a valid id"
        end
      end
      should_not_change "Helpdesk::Subscription.count"
    end

    context "on delete to destroy with valid id" do
      setup do
        @subscription = Helpdesk::Subscription.create(:user => @user, :ticket => @ticket)
        delete :destroy, :ticket_id => @ticket.to_param, :id => @subscription.id
      end

      should_redirect_to back
      should_assign_to :items

      # Because we both create and destroy the subscription during setup
      should_not_change "Helpdesk::Subscription.count"

      should "set flash" do
        assert_match(/^1 subscription was deleted/, flash[:notice])
      end

      should "deleted record" do
        assert !Helpdesk::Subscription.find_by_id(@subscription.id)
      end
    end


    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "subscription", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_subscription", @controller.nscname
      end

      context "controller loaded with mock @parent" do
        setup do
          @parent = mock
          @subscriptions = mock
          @subscriptions.stubs(:find_by_id).with(999).returns(:some_subscription)
          @subscriptions.stubs(:find_by_id).with(666).returns(nil)
          @parent.stubs(:subscriptions).returns(@subscriptions)
          @controller.instance_variable_set('@parent', @parent) 
        end

        should "return correct scoper" do
          assert_same @subscriptions, @controller.scoper
        end

        should "find called when load by param is called" do
          assert_equal :some_subscription, @controller.load_by_param(999)
        end

        should "fetch item when load_item called" do
          @controller.expects(:params).returns({:id => 999})
          assert_equal :some_subscription, @controller.load_item
        end

        should "render not found if load_item called with invalid id" do
          @controller.expects(:params).returns({:id => 666})
          assert_raise ActiveRecord::RecordNotFound do
            @controller.load_item
          end
        end

        should "build a new ticket from params" do
          params = {'name' => "bill"}
          @subscriptions.expects(:build).with(params).returns(:new_record)
          @controller.expects(:params).returns({'helpdesk_subscription' => params})
          assert_same :new_record, @controller.build_item
        end

      end

    end

  end
end
