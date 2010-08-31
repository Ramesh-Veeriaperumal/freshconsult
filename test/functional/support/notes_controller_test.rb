require 'test_helper'

class Support::NotesControllerTest < ActionController::TestCase
  context "allow all" do
    setup do
      allow_all
      stub_user
      set_referrer
    end


    context "on valid post to create" do
      setup do
        @ticket = Helpdesk::Ticket.first
        @params = {:body => 'this is a new note'}
        post :create, :helpdesk_note => @params, :ticket_id => @ticket.to_param
      end
      should_redirect_to back
      should_set_the_flash_to "The note has been added to your request."
      should_change "Helpdesk::Note.count", :by => 1
      should "create note with @params" do
        note = Helpdesk::Note.last
        @params.each { |k, v| assert_equal v, note.send(k) }
      end
    end

    context "on invalid post to create" do
      setup do
        @ticket = Helpdesk::Ticket.first
        @params = {:body => ''}
        post :create, :helpdesk_note => @params, :ticket_id => @ticket.to_param
      end
      should_redirect_to back
      should_not_change "Helpdesk::Note.count"
      should_set_the_flash_to "There was a problem adding the note to your request. Please try again."
    end

    context "on post to create with invalid ticket_id" do
      setup do
        @params = {:body => ''}
        assert_raise ActiveRecord::RecordNotFound do
          post :create, :helpdesk_note => @params, :ticket_id => "fail!"
        end
      end
      should_not_change "Helpdesk::Note.count"
    end
  end
end
