module NoteTestHelper 
  def create_note(params = {})
    test_note = FactoryGirl.build(:helpdesk_note,
                         :source => params[:source] || Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
                         :notable_id => params[:ticket_id] || Helpdesk::Ticket.last.id,
                         :created_at => params[:created_at],
                         :user_id => params[:user_id] || @agent.id,
                         :account_id => @account.id,
                         :notable_type => 'Helpdesk::Ticket')
    test_note.incoming = params[:incoming] if params[:incoming]
    test_note.private = params[:private] if params[:private]
    test_note.category = params[:category] if params[:category]
    test_note.build_note_body(:body => params[:body],
                              :body_html => params[:body_html] || params[:body])
    test_note.save_note
    test_note
  end

  def create_broadcast_note(params={})
    broadcast_params = {:private => true,
     :category => Helpdesk::Note::CATEGORIES[:broadcast]
    }.merge(params)
    create_note broadcast_params
  end

  def broadcast_note_params(options={})
    params = options.merge(:private => true, :category => Helpdesk::Note::CATEGORIES[:broadcast])
    note_params params
  end

  def note_params(params={})
    params_hash = {:helpdesk_note => { 
                                      :note_body_attributes => { :body_html => params[:body] || Faker::Lorem.paragraph}, 
                                      :source => params[:source] || Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
                                      :category => params[:category],
                                      :private => params[:private],
                                     },
                    :ticket_id => params[:ticket_id] || Helpdesk::Ticket.first.id,
                  }
  end
end