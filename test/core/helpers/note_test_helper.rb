module NoteTestHelper
  def create_note(params = {})
    test_note = FactoryGirl.build(:helpdesk_note,
                         :source => params[:source] || Account.current.helpdesk_sources.note_source_keys_by_token["note"],
                         :notable_id => params[:ticket_id] || Helpdesk::Ticket.last.id,
                         :created_at => params[:created_at],
                         :user_id => params[:user_id] || @agent.id,
                         :account_id => @account.id,
                         :notable_type => 'Helpdesk::Ticket')
    test_note.incoming = params[:incoming] if params[:incoming]
    test_note.private = params[:private] if params[:private]
    test_note.category = params[:category] if params[:category]
    test_note.send_survey = params[:send_survey] if params[:send_survey]
    body = params[:body] || Faker::Lorem.paragraph
    test_note.build_note_body(:body => body, :body_html => params[:body_html] || body)
    if params[:attachments]
      params[:attachments].each do |attach|
        test_note.attachments.build(:content => attach[:resource], 
                                      :description => attach[:description], 
                                      :account_id => test_note.account_id)
      end
    end
    if params[:source_additional_info].present?
      twitter_params = params[:source_additional_info][:twitter]
      if twitter_params.present?
        test_note.build_tweet(tweet_id: twitter_params[:tweet_id],
                              tweet_type: twitter_params[:tweet_type],
                              twitter_handle_id: twitter_params[:twitter_handle_id],
                              stream_id: twitter_params[:stream_id])
      end
    end
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
                                      :source => params[:source] || Account.current.helpdesk_sources.note_source_keys_by_token["note"],
                                      :category => params[:category],
                                      :private => params[:private],
                                     },
                    :ticket_id => params[:ticket_id] || Helpdesk::Ticket.first.id,
                  }
  end

  def create_note_with_attachments(params = {})
    file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
    attachments = [{:resource => file}]
    create_note(params.merge({:attachments => attachments}))
  end

  def create_note_with_multiple_attachments(params = {})
    attachments = []
    params[:num_of_files].times do
      file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
      attachments << { resource: file }
    end
    create_note(params.merge(attachments: attachments))
  end

  def create_note_with_multiple_attachments(params = {})
    attachments = []
    params[:num_of_files].times do
      file = File.new(Rails.root.join("spec/fixtures/files/attachment.txt"))
      attachments << { resource: file }
    end
    create_note(params.merge(attachments: attachments))
  end

  # def create_note_with_freshcaller(params = {})
  #   test_note = create_note(params)
  #   call_obj = build_call
  #   link_and_create(call_obj, test_note)
  #   test_note
  # end

  def create_note_with_survey_result(ticket, params = {})
    note = create_note(note_params_hash({:source => Account.current.helpdesk_sources.note_source_keys_by_token["feedback"]}))
    survey = @account.surveys.first
    survey.send_while = 4
    survey.save
    survey_handle = @ticket.survey_handles.build
    survey_handle.survey = survey
    survey_handle.response_note_id = note.id
    survey_handle.save!
    survey_handle.create_survey_result(Survey::HAPPY)
    survey_result = survey_handle.survey_result
    survey_result.build_survey_remark({:note_id => note.id})
    survey_result.save!
    note
  end

  def create_note_with_notifier(_ticket, _params = {})
    note = create_note(note_params_hash(source: Account.current.helpdesk_sources.note_source_keys_by_token['feedback']))
    schema_less_note = @account.schema_less_notes.find_by_note_id(note.id)
    schema_less_note.to_emails = [@account.users.first.email]
    schema_less_note.save
    survey = @account.surveys.first
    survey.send_while = 4
    survey.save
    survey_handle = @ticket.survey_handles.build
    survey_handle.survey = survey
    survey_handle.response_note_id = note.id
    survey_handle.save!
    survey_handle.create_survey_result(Survey::HAPPY)
    survey_result = survey_handle.survey_result
    survey_result.build_survey_remark(note_id: note.id)
    survey_result.save!
    note
  end
end