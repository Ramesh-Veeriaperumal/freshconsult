require 'test_helper'

class Helpdesk::TagUsesControllerTest < ActionController::TestCase
  context "all permissions granted" do
    setup do
      stub_user
      allow_all
      set_referrer
    end

    
    context "on post to create with valid params and existing tag" do
      setup do
        @ticket = Helpdesk::Ticket.first
        @tag = Helpdesk::Tag.first
        @ticket.tag_uses.clear
        @tag.tag_uses.clear
        post :create, :ticket_id => @ticket.to_param, :name => @tag.name
      end

      should_redirect_to back
      should_set_the_flash_to "The tag was added"
      should_not_change "Helpdesk::Tag.count"
      should_change "Helpdesk::TagUse.count", 1

      should "add tag to ticket" do
        @ticket.reload
        @tag.reload
        assert_equal @ticket.tags.first, @tag
        assert_equal @tag.tickets.first, @ticket
      end
    end

    context "on post to create, trying to add tag twice" do
      setup do
        @ticket = Helpdesk::Ticket.first
        @tag = Helpdesk::Tag.first
        post :create, :ticket_id => @ticket.to_param, :name => @tag.name
      end

      should_redirect_to back
      should_set_the_flash_to "The tag was added"
      should_not_change "Helpdesk::Tag.count"
      should_not_change "Helpdesk::TagUse.count"

      should "have tag" do
        @ticket.reload
        @tag.reload
        assert_equal @ticket.tags.first, @tag
        assert_equal @tag.tickets.first, @ticket
      end
    end

    context "on post to create with valid params and non-existant tag" do
      setup do
        @ticket = Helpdesk::Ticket.first
        post :create, :ticket_id => @ticket.to_param, :name => "New Tag"
      end

      should_redirect_to back
      should_set_the_flash_to "The tag was added"
      should_change "Helpdesk::Tag.count", 1
      should_change "Helpdesk::TagUse.count", 1

      should "create tag" do
        assert Helpdesk::Tag.find_by_name("New Tag")
      end
    end

    context "on post to create with invalid ticket id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          post :create, :ticket_id => "invalid id", :name => "New Tag"
        end
      end
      should_not_change "Helpdesk::Tag.count"
      should_not_change "Helpdesk::TagUse.count"
    end

    context "on delete to destroy with valid params" do
      setup do
        @ticket = Helpdesk::Ticket.first
        @tag = Helpdesk::Tag.first
        delete :destroy, :ticket_id => @ticket.to_param, :id => @tag.to_param
      end

      should_redirect_to back
      should_set_the_flash_to "The tag was removed from this ticket"
      should_not_change "Helpdesk::Tag.count"
      should_change "Helpdesk::TagUse.count", -1

      should "remove tag from ticket" do
        @ticket.reload
        @tag.reload
        assert !@ticket.tags.include?(@tag)
      end
    end

    context "on delete to destroy with invalid ticket_id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          delete :destroy, :ticket_id => "invalid id", :id => Helpdesk::Tag.first.to_param
        end
      end
      should_not_change "Helpdesk::Tag.count"
      should_not_change "Helpdesk::TagUse.count"
    end

    context "on delete to destroy with invalid tag_id" do
      setup do
        assert_raise ActiveRecord::RecordNotFound do
          delete :destroy, :ticket_id => Helpdesk::Ticket.first.to_param, :id => "invalid id"
        end
      end
      should_not_change "Helpdesk::Tag.count"
      should_not_change "Helpdesk::TagUse.count"
    end


  end
end
