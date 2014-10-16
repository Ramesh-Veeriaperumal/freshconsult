module NoteHelper

  def create_note(params = {})
    test_note = FactoryGirl.build(:helpdesk_note, :source => params[:source],
                                         :notable_id => params[:ticket_id],
                                         :created_at => params[:created_at],
                                         :user_id => params[:user_id],
                                         :account_id => @account.id,
                                         :notable_type => 'Helpdesk::Ticket')
    test_note.incoming = params[:incoming] if params[:incoming]
    test_note.private = params[:private] if params[:private]
    test_note.build_note_body(:body => params[:body], :body_html => params[:body])
    test_note.save_note
    test_note
  end
end
