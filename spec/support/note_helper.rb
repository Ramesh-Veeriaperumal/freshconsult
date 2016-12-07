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

  def note_params(params_hash={})
    params = {:body_html => Faker::Lorem.paragraph}
    params[:private] = params_hash[:private] unless params_hash[:private].nil?
    params[:user_id] = params_hash[:user_id] if params_hash[:user_id]
    params.merge!({:attachments => [{:resource => params_hash[:file]}] }) unless params_hash[:file].nil?
    {:helpdesk_note => params}
  end

  def create_private_note(ticket)
    note = create_note(source: 2, ticket_id: ticket.id, user_id: @agent.id, private: true, body: Faker::Lorem.paragraph)
    note.reload
  end

  def create_reply_note(ticket)
    note = create_note(source: 0, ticket_id: ticket.id, user_id: user.id, private: false, body: Faker::Lorem.paragraph)
    note.reload
  end

  def create_forward_note(ticket)
    note = create_note(source: 8, ticket_id: ticket.id, user_id: @agent.id, private: false, body: Faker::Lorem.paragraph)
    note.reload
  end

  def create_feedback_note(ticket)
    survey_result = create_survey_result(ticket, 100, nil, create_survey(1))
    survey_result.surveyable.notes.last
  end

  def create_fb_note(ticket)
    note = create_note(source: 7, ticket_id: ticket.id, user_id: user.id, private: false, body: Faker::Lorem.paragraph)
    fb_page = create_facebook_page(true)
    note.build_fb_post(post_id: get_social_id, facebook_page_id: fb_page.id, msg_type: 'post',
                        post_attributes: { can_comment: false, post_type: 2 })
    note.save
    note.reload
  end

  def create_twitter_note(ticket)
    note = create_note(source: 5, ticket_id: ticket.id, user_id: user.id, private: false, body: Faker::Lorem.paragraph)
    note.build_tweet(tweet_id: 12345, tweet_type: 'mention', twitter_handle_id: get_twitter_handle.id)
    note.save
    note.reload
  end
end
