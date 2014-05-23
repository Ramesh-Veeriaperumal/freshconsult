require File.expand_path("#{File.dirname(__FILE__)}/../spec_helper")

module NoteHelper

  def create_note(params = {})
    
    test_note = Factory.build(:helpdesk_note, :source => params[:source],
                                         :notable_id => params[:ticket_id],
                                         :created_at => params[:created_at],
                                         :user_id => params[:requester_id],
                                         :account_id => @account.id,
                                         :notable_type => 'Helpdesk::Ticket')
    test_note.build_note_body(:body => params[:body], :body_html => params[:body])
    test_note.save_note
    test_note
  end
end