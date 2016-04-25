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

  def test_normal_agent_ticket_by_complete_display_id
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_display_id
    log_out
    log_in(@agent)

    ticket = create_ticket({ display_id: 215200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => '215'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_subject
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_subject
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_complete_description
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_partial_description
    log_out
    log_in(@agent)

    ticket = create_ticket
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description[0..10]

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

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

    get :tickets, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_normal_agent_ticket_by_attachment_name
    log_out
    log_in(@agent)

    ticket = create_ticket(:attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')})
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.attachments.first.content_file_name.split('.').first

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

    get :tickets, :term => ticket.send("es_line_text_#{@account.id}")

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

    get :tickets, :term => ticket.send("es_line_para_#{@account.id}")

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_display_id
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_display_id
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({ display_id: 216200 }, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => '216'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_subject
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_subject
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_complete_description
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_partial_description
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({}, @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description[0..10]

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

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

    get :tickets, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_group_agent_ticket_by_attachment_name
    log_out
    log_in(@@group_agent)

    ticket = create_ticket({:attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')}},
            @@group_agent.agent.groups.first)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.attachments.first.content_file_name.split('.').first

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

    get :tickets, :term => ticket.send("es_line_text_#{@account.id}")

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

    get :tickets, :term => ticket.send("es_line_para_#{@account.id}")

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_display_id
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.display_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_display_id
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id, display_id: 217200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => '217'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_subject
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_subject
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.subject[0..10]

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_complete_description
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_partial_description
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ responder_id: @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.description[0..10]

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:cc_emails].first.split('@').last

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first

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

    get :tickets, :term => ticket.cc_email_hash[:fwd_emails].first.split('@').last

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

    get :tickets, :term => ticket.tags.first.name

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end

  def test_restricted_agent_ticket_by_attachment_name
    log_out
    log_in(@@restricted_agent)

    ticket = create_ticket({ :attachments => {:resource => fixture_file_upload('files/facebook.png','image/png')},
            :responder_id => @@restricted_agent.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    get :tickets, :term => ticket.attachments.first.content_file_name.split('.').first

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

    get :tickets, :term => ticket.send("es_line_text_#{@account.id}")

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

    get :tickets, :term => ticket.send("es_line_para_#{@account.id}")

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

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

    get :tickets, :term => note.body

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

    get :tickets, :term => 'Tel pop sta'

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, ticket.id
  end
end