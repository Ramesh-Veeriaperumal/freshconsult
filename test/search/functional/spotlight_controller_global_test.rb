require_relative '../test_helper'

class Search::V2::SpotlightControllerTest < ActionController::TestCase

  def setup
    super
    # Adding group and restricted agents
    role_id = @account.roles.find_by_name("Agent").id
    @@group_agent ||= add_agent(@account, {
      :name => Faker::Name.name,
      :email => Faker::Internet.email,
      :active => 1,
      :role => role_id,
      :agent => 1,
      :ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:group_tickets],
      :group_id => @account.groups.first.id,
      :role_ids => ["#{role_id}"]
    })
    @@restricted_agent ||= add_agent(@account, {
      :name => Faker::Name.name,
      :email => Faker::Internet.email,
      :active => 1,
      :role => role_id,
      :agent => 1,
      :ticket_permission => Agent::PERMISSION_KEYS_BY_TOKEN[:assigned_tickets],
      :role_ids => ["#{role_id}"]
    })
  end

  ###############
  # Ticket Spec #
  ###############

  def test_normal_agent_ticket_by_complete_display_id
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_display_id
    log_out
    log_in(@agent)

    ticket = create_ticket({ display_id: 215200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => '215'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_subject
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_subject
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_description
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_description
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_cc_email
    log_out
    log_in(@agent)

    ticket = create_ticket
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_cc_email_domain
    log_out
    log_in(@agent)

    ticket = create_ticket
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_fwd_email
    log_out
    log_in(@agent)

    ticket = create_ticket
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_fwd_email_domain
    log_out
    log_in(@agent)

    ticket = create_ticket
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_tag_name
    log_out
    log_in(@agent)

    ticket = create_ticket
    ticket.tags.create(FactoryGirl.attributes_for(:tag))
    ticket.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_attachment_name
    log_out
    log_in(@agent)

    ticket = create_ticket(:attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')})
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.attachments.first.content_file_name.split('.').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_single_line_text
    log_out
    log_in(@agent)

    create_custom_field('es_line_text','text')
    ticket = create_ticket
    ticket.send("es_line_text_#{@account.id}=", Faker::Lorem.sentence)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_text_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_para_text
    log_out
    log_in(@agent)

    create_custom_field('es_line_para','paragraph')
    ticket = create_ticket
    ticket.send("es_line_para_#{@account.id}=", Faker::Lorem.paragraph)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_para_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_public_note_body
    log_out
    log_in(@agent)

    ticket = create_ticket({ :responder_id => @agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_public_note_body
    log_out
    log_in(@agent)

    ticket = create_ticket({ :responder_id => @agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_private_note_body
    log_out
    log_in(@agent)

    ticket = create_ticket({ :responder_id => @agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_private_note_body
    log_out
    log_in(@agent)

    ticket = create_ticket({ :responder_id => @agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_display_id
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_display_id
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ display_id: 216200 }, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => '216'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_subject
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_subject
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_description
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_description
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_cc_email
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_cc_email_domain
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_fwd_email
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_fwd_email_domain
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_tag_name
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.tags.create(FactoryGirl.attributes_for(:tag))
    ticket.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_attachment_name
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({:attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')}},
            @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.attachments.first.content_file_name.split('.').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_single_line_text
    log_out
    log_in(@@group_agent)

    create_custom_field('es_line_text','text')
    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.send("es_line_text_#{@account.id}=", Faker::Lorem.sentence)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_text_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_para_text
    log_out
    log_in(@@group_agent)

    create_custom_field('es_line_para','paragraph')
    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    ticket.send("es_line_para_#{@account.id}=", Faker::Lorem.paragraph)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_para_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_public_note_body
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ :responder_id => @@group_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_public_note_body
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ :responder_id => @@group_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_private_note_body
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ :responder_id => @@group_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_private_note_body
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ :responder_id => @@group_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_display_id
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_display_id
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id, display_id: 217200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => '217'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_subject
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_subject
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_description
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_description
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_cc_email
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_cc_email_domain
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    ticket.cc_email = { :cc_emails => ["superman@justiceleague.com"], :fwd_emails => [], :reply_cc => ["superman@justiceleague.com"] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_fwd_email
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_fwd_email_domain
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    ticket.cc_email = { :cc_emails => [], :fwd_emails => ["superman@justiceleague.com"], :reply_cc => [] }
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_tag_name
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    ticket.tags.create(FactoryGirl.attributes_for(:tag))
    ticket.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_attachment_name
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')},
            :responder_id => @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.attachments.first.content_file_name.split('.').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_single_line_text
    log_out
    log_in(@@restricted_agent)

    create_custom_field('es_line_text','text')
    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    ticket.send("es_line_text_#{@account.id}=", Faker::Lorem.sentence)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_text_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_para_text
    log_out
    log_in(@@restricted_agent)

    create_custom_field('es_line_para','paragraph')
    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    ticket.send("es_line_para_#{@account.id}=", Faker::Lorem.paragraph)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => ticket.send("es_line_para_#{@account.id}")

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_public_note_body
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_public_note_body
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: false,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_private_note_body
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Football is soccer in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => note.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_private_note_body
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :responder_id => @@restricted_agent.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @agent.id,
                          private: true,
                          body: 'Television series are very popular in the states.'
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :all, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  #############
  # User Spec #
  #############

  def test_user_by_complete_name
    user = add_new_user(@account, { name: Faker::Name.name })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_name
    user = add_new_user(@account, { name: Faker::Name.name })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_primary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_primary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email.split('@').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_primary_email_domain
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.email.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_secondary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_secondary_email
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email.split('@').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_secondary_email_domain
    user = add_user_with_multiple_emails(@account, 2)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.user_emails.where(primary_role: false).first.email.split('@').last

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_description
    user = add_new_user(@account)
    user.update_attribute(:description, Faker::Lorem.sentence)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_description
    user = add_new_user(@account)
    user.update_attribute(:description, Faker::Lorem.sentence)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_job_title
    user = add_new_user(@account)
    user.update_attribute(:job_title, 'Senior Product Developer')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.job_title

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_job_title
    user = add_new_user(@account)
    user.update_attribute(:job_title, 'Senior Account Manager')
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: 'Acc Man'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_phone
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.phone

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_phone
    user = add_new_user_without_email(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.phone[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_mobile
    user = add_new_user_without_email(@account)
    user.update_attribute(:mobile, Faker::PhoneNumber.phone_number)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.mobile

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_mobile
    user = add_new_user_without_email(@account)
    user.update_attribute(:mobile, Faker::PhoneNumber.phone_number)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.mobile[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_company_name
    company = create_company
    user = add_new_user(@account, { customer_id: company.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.company.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_company_name
    company = create_company
    user = add_new_user(@account, { customer_id: company.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.company.name[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_twitter_id
    user = add_new_user_with_twitter_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.twitter_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_twitter_id
    user = add_new_user_with_twitter_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.twitter_id[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_complete_fb_profile_id
    user = add_new_user_with_fb_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.fb_profile_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  def test_user_by_partial_fb_profile_id
    user = add_new_user_with_fb_id(@account)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: user.fb_profile_id[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, user.id
  end

  # def test_user_by_complete_line_text
  #   create_contact_field(cf_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   user = add_new_user(@account)
  #   cf_val = Faker::Address.country
  #   user.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_partial_line_text
  #   create_contact_field(cf_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   user = add_new_user(@account)
  #   cf_val = Faker::Address.country
  #   user.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[0..2]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_complete_para_text
  #   create_contact_field(cf_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   user = add_new_user(@account)
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   user.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val.join(' ')

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id
  # end

  # def test_user_by_partial_para_text
  #   create_contact_field(cf_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   user = add_new_user(@account)
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   user.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[Random.rand(0..2)][0..3]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, user.id

  ################
  # Company Spec #
  ################

  def test_company_by_complete_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_name
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.name[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_complete_note
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.note

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_note
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.note[0..5]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_complete_description
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_description
    company = create_company
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: company.description[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  # def test_company_by_complete_line_text
  #   create_company_field(company_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   company = create_company
  #   cf_val = Faker::Address.country
  #   company.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_partial_line_text
  #   create_company_field(company_params({ type: 'text', field_type: 'custom_text', label: 'Country' }))
  #   company = create_company
  #   cf_val = Faker::Address.country
  #   company.update_attributes(custom_field: { cf_country: cf_val })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[0..2]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_complete_para_text
  #   create_company_field(company_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   company = create_company
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   company.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val.join(' ')

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  # def test_company_by_partial_para_text
  #   create_company_field(company_params({ type: 'paragraph', field_type: 'custom_paragraph', label: 'Teams' }))
  #   company = create_company
  #   cf_val = 3.times.collect { Faker::Team.name }
  #   company.update_attributes(custom_field: { cf_teams: cf_val.join(',') })
  #   sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

  #   get :customers, term: cf_val[Random.rand(0..2)][0..3]

  #   res_body = parsed_attr(response.body, 'id')
  #   assert_includes res_body, company.id
  # end

  def test_company_by_complete_domains
    company = create_company
    domains = 3.times.collect { Faker::Internet.domain_name }
    company.update_attribute(:domains, domains.join(','))
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: domains.first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  def test_company_by_partial_domains
    company = create_company
    domains = 3.times.collect { Faker::Internet.domain_name }
    company.update_attribute(:domains, domains.join(','))
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :customers, term: domains.last[0..2]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, company.id
  end

  ##############
  # Topic Spec #
  ##############

  def test_topic_by_complete_title
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :forums, term: topic.title

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_complete_title
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :forums, term: topic.title, category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_by_partial_title
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :forums, term: topic.title[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_partial_title
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :forums, term: topic.title[0..3], category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_by_complete_post_content
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.body

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_complete_post_content
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.body, category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_by_partial_post_content
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.body[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_partial_post_content
    topic = create_test_topic(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.body[0..3], category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_by_complete_attachment_name
    topic = create_test_topic_with_attachments(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.attachments.first.content_file_name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_complete_attachment_name
    topic = create_test_topic_with_attachments(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.attachments.first.content_file_name, category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  ################
  # Article Spec #
  ################

  def test_article_by_complete_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 2, 
      art_type: 1 
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: article.title

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_complete_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 2, 
      art_type: 1 
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: article.title, folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_complete_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 2, 
      art_type: 1 
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: article.title, category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_by_partial_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_partial_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3], folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_partial_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3], category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_by_complete_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_complete_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name, folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_complete_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name, category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_by_partial_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_partial_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3], folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_partial_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for #{team_name}'s tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 2
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name[0..3], category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_by_complete_tag_name
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1
    })
    article.tags.create(name: team_name)
    article.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_complete_tag_name
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1
    })
    article.tags.create(name: team_name)
    article.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name, folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_complete_tag_name
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1
    })
    article.tags.create(name: team_name)
    article.send :update_searchv2 #=> To trigger reindex
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: team_name, category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_by_attachment_name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: 'facebook'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_folder_id_by_attachment_name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: 'facebook', folder_id: article.folder_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end

  def test_article_with_category_id_by_attachment_name
    article = create_article({ 
      title: "Collecting Donations", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.first.id, 
      status: 1, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :solutions, term: 'facebook', category_id: article.folder.category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, article.id
  end
end