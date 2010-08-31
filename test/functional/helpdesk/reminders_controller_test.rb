require 'test_helper'

class Helpdesk::RemindersControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    context "on valid post to create with no ticket id" do
      setup do
        @params = {:body => 'new body'}
        post :create, :helpdesk_reminder => @params
      end
      should_redirect_to back
      should_assign_to :item, :reminder
      should_set_the_flash_to "The reminder has been created"
      should_change "Helpdesk::Reminder.count", 1
      should "have created the reminder" do
        reminder = Helpdesk::Reminder.last
        assert_equal @params[:body], reminder.body
        assert_equal @user, reminder.user
        assert !reminder.ticket
        
      end
    end

    context "on invalid post to create with no ticket id" do
      setup do
        @params = {:body => ''}
        post :create, :helpdesk_reminder => @params
      end
      should_redirect_to back
      should_assign_to :item, :reminder
      should_not_set_the_flash
      should_not_change "Helpdesk::Reminder.count"
    end

    context "on post to create with invalid ticket id" do
      setup do
        @params = {:body => 'somebody'}
        post :create, :helpdesk_reminder => @params, :ticket_id => "invalid id"
      end
      should_redirect_to back
      should_assign_to :item, :reminder
      should_change "Helpdesk::Reminder.count", 1
      should_set_the_flash_to "The reminder has been created"
      should "have created the reminder with no ticket" do
        reminder = Helpdesk::Reminder.last
        assert_equal @params[:body], reminder.body
        assert_equal @user, reminder.user
        assert !reminder.ticket
      end
    end

    context "on post to create with valid ticket id" do
      setup do
        @params = {:body => 'somebody'}
        @ticket = Helpdesk::Ticket.first
        post :create, :helpdesk_reminder => @params, :ticket_id => @ticket.to_param
      end
      should_redirect_to back
      should_assign_to :item, :reminder
      should_change "Helpdesk::Reminder.count", 1
      should_set_the_flash_to "The reminder has been created"
      should "have created the reminder with no ticket" do
        reminder = Helpdesk::Reminder.last
        assert_equal @params[:body], reminder.body
        assert_equal @user, reminder.user
        assert_equal @ticket, reminder.ticket
      end
    end

    context "on delete to destroy with valid id" do
      setup do
        @reminder = Helpdesk::Reminder.create(:body => "somebody", :user => @user, :deleted => false)
        delete :destroy, :id => @reminder.id
      end

      should_assign_to :items
      should_redirect_to back

      should "set flash" do
        assert_match(/^1 reminder was deleted/, flash[:notice])
      end

      should "set deleted flag" do
        @reminder.reload
        assert @reminder.deleted
      end
    end


    context "controller's private and protected methods made public" do
      setup { publicize_controller_methods }
      teardown { privatize_controller_methods }

      should "return class_name from Namespace::ClassName" do
        assert_equal "reminder", @controller.cname
      end

      should "return namespace_class_name from Namespace::ClassName" do
        assert_equal "helpdesk_reminder", @controller.nscname
      end

      should "return correct scoper" do
        assert_same Helpdesk::Reminder, @controller.scoper
      end

      should "find_by_id_token when load by param is called" do
        Helpdesk::Reminder.expects(:find_by_id).with(999).returns(:some_value)
        assert_equal :some_value, @controller.load_by_param(999)
      end

      should "fetch item when load_item called" do
        Helpdesk::Reminder.expects(:find_by_id).with(999).returns(:some_value)
        @controller.expects(:params).returns({:id => 999})
        assert_equal :some_value, @controller.load_item
      end

      should "render not found if load_item called with invalid id" do
        Helpdesk::Reminder.expects(:find_by_id).with(999).returns(nil)
        @controller.expects(:params).returns({:id => 999})
        assert_raise ActiveRecord::RecordNotFound do
          @controller.load_item
        end
      end

      should "build a new reminder from params" do
        @controller.expects(:params).returns({'helpdesk_reminder' => {'body' => "A reminder"}})
        reminder = @controller.build_item
        assert_equal "A reminder", reminder.body
      end

    end

  end
end
