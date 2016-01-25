require_relative '../test_helper'

class Support::SearchV2::SpotlightControllerTest < ActionController::TestCase

  def setup
    super
    @ticket_contact = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)

    @article_contact = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)

    @logged_folder = @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users]).try(:first) || create_folder({
      name: 'ES Testing One',
      category_id: @account.solution_categories.last.id,
      visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
    })

    @company_folder = @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).try(:first) || create_folder({
      name: 'ES Testing Two',
      category_id: @account.solution_categories.last.id,
      visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    })
    create_customer_folders(@company_folder)
    @company_article_contact = FactoryGirl.build(:user, :account => @account, 
                                                :email => Faker::Internet.email, 
                                                :user_role => 3,
                                                :privileges => Role.privileges_mask([:client_manager]),
                                                :customer_id => @company_folder.customer_ids.first)

    @default_forum = @account.forums.first
    @logged_forum = @account.forums.where(forum_visibility: Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]).try(:first) || create_test_forum(
      @account.forum_categories.first,
      Forum::TYPE_KEYS_BY_TOKEN[:ideas],
      Forum::VISIBILITY_KEYS_BY_TOKEN[:logged_users]
    )
    @company_forum = @account.forums.where(forum_visibility: Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]).try(:first) || create_test_forum(
      @account.forum_categories.first,
      Forum::TYPE_KEYS_BY_TOKEN[:ideas],
      Forum::VISIBILITY_KEYS_BY_TOKEN[:company_users]
    )
    create_customer_forums(@company_forum)

    @topic_contact = FactoryGirl.build(:user, :account => @account, :email => Faker::Internet.email, :user_role => 3)
    @company_forum_contact = FactoryGirl.build(:user, :account => @account, 
                                                :email => Faker::Internet.email, 
                                                :user_role => 3,
                                                :privileges => Role.privileges_mask([:client_manager]),
                                                :customer_id => @company_forum.customer_forums.pluck(:customer_id).first)
  end

  ###############
  # Ticket Spec #
  ###############

  def test_ticket_by_complete_display_id
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.display_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_display_id
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id, display_id: 315200 })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: '315'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_subject
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.subject

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_subject
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.subject[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_description
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.description

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_description
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.description[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_to_email
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.to_emails = [Faker::Internet.email]
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.to_emails.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_to_email
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.to_emails = [Faker::Internet.email]
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: ticket.to_emails.first.split('@').first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_cc_email
    log_in(@ticket_contact)
    cc_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @ticket_contact.id, cc_emails: cc_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: cc_email.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_cc_email
    log_in(@ticket_contact)
    cc_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @ticket_contact.id, cc_emails: cc_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: cc_email.first[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_fwd_email
    log_in(@ticket_contact)
    fwd_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @ticket_contact.id, fwd_emails: fwd_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: fwd_email.first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_fwd_email
    log_in(@ticket_contact)
    fwd_email = [Faker::Internet.email]
    ticket = create_ticket({ requester_id: @ticket_contact.id, fwd_emails: fwd_email })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: fwd_email.first[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_line_text
    log_in(@ticket_contact)
    city = Faker::Address.city
    c_field = create_custom_field('es_region','text')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.send("es_region_#{@account.id}=", city)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: city

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_line_text
    log_in(@ticket_contact)
    city = Faker::Address.city
    c_field = create_custom_field('es_region','text')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.send("es_region_#{@account.id}=", city)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: city[0..3]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_para_text
    log_in(@ticket_contact)
    nouns = Faker::Hacker.noun
    c_field = create_custom_field('es_nouns','paragraph')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.send("es_nouns_#{@account.id}=", nouns)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: nouns

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_para_text
    log_in(@ticket_contact)
    nouns = Faker::Hacker.noun
    c_field = create_custom_field('es_nouns','paragraph')
    c_field.update_column(:visible_in_portal, true)
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    ticket.send("es_nouns_#{@account.id}=", nouns)
    ticket.save
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: nouns[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_complete_public_note
    log_in(@ticket_contact)
    dept = Faker::Commerce.department
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @ticket_contact.id,
                          private: false,
                          body: "Report from the department of #{dept}"
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: dept

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_partial_public_note
    log_in(@ticket_contact)
    dept = Faker::Commerce.department
    ticket = create_ticket({ requester_id: @ticket_contact.id })
    note = create_note({ 
                          source: Helpdesk::Note::SOURCE_KEYS_BY_TOKEN['note'],
                          ticket_id: ticket.id,
                          user_id: @ticket_contact.id,
                          private: false,
                          body: "Report from the department of #{dept}"
                        })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: dept[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  def test_ticket_by_attachment_name
    log_in(@ticket_contact)
    ticket = create_ticket({ requester_id: @ticket_contact.id,
      attachments: { resource: fixture_file_upload('files/facebook.png', 'image/jpeg') } })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :tickets, term: 'facebook'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/tickets/#{ticket.display_id}"
  end

  ################
  # Article Spec #
  ################

  def test_article_with_any_visibility_by_complete_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_complete_title
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_complete_title
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_complete_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_complete_title
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_complete_title
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.title, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_by_partial_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_partial_title
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_partial_title
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_partial_title
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_partial_title
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_partial_title
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for #{team_name}", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: team_name[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_by_complete_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_complete_desc_un_html
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_complete_desc_un_html
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_complete_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_complete_desc_un_html
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_complete_desc_un_html
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_by_partial_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_partial_desc_un_html
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_partial_desc_un_html
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_partial_desc_un_html
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_partial_desc_un_html
    log_in(@article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_partial_desc_un_html
    log_in(@company_article_contact)
    team_name = Faker::Team.name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for #{team_name}'s' tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: article.desc_un_html[0..5], category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_by_complete_tag_name
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_complete_tag_name
    log_in(@article_contact)
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_complete_tag_name
    log_in(@company_article_contact)
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_complete_tag_name
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_complete_tag_name
    log_in(@article_contact)
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_complete_tag_name
    log_in(@company_article_contact)
    tag_name = Faker::Address.country
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1
    })
    article.tags.create(name: tag_name)
    article.send :update_searchv2
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: tag_name, category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_by_attachment_name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_by_attachment_name
    log_in(@article_contact)
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_by_attachment_name
    log_in(@company_article_contact)
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook'

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_any_visibility_with_category_id_by_attachment_name
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:anyone]).first.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook', category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_logged_visibility_with_category_id_by_attachment_name
    log_in(@article_contact)
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @logged_folder.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook', category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  def test_article_with_company_visibility_with_category_id_by_attachment_name
    log_in(@company_article_contact)
    article = create_article({ 
      title: "Donations for team", 
      description: "Raising funds to be used for tournaments", 
      folder_id: @account.folders.where(visibility: Solution::Folder::VISIBILITY_KEYS_BY_TOKEN[:company_users]).first.id, 
      status: 2, 
      art_type: 1,
      attachments: { resource: fixture_file_upload('files/facebook.png','image/png') }
    })
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES

    xhr :get, :solutions, term: 'facebook', category_id: article.folder.category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/solutions/articles/#{article.id}-#{article.title.parameterize}"
  end

  ##############
  # Topic Spec #
  ##############

  def test_topic_with_any_visibility_by_complete_title
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_by_complete_title
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_by_complete_title
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_with_category_id_by_complete_title
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_with_category_id_by_complete_title
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_with_category_id_by_complete_title
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_by_partial_title
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_by_partial_title
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_by_partial_title
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_with_category_id_by_partial_title
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_with_category_id_by_partial_title
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_with_category_id_by_partial_title
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.title[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_by_complete_post_body
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_by_complete_post_body
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_by_complete_post_body
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_with_category_id_by_complete_post_body
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_with_category_id_by_complete_post_body
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_with_category_id_by_complete_post_body
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_by_partial_post_body
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_by_partial_post_body
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_by_partial_post_body
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5]

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_with_category_id_by_partial_post_body
    topic = create_test_topic(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_with_category_id_by_partial_post_body
    log_in(@topic_contact)
    topic = create_test_topic(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_with_category_id_by_partial_post_body
    log_in(@company_forum_contact)
    topic = create_test_topic(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.body[0..5], category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_by_complete_attachment_name
    topic = create_test_topic_with_attachments(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_by_complete_attachment_name
    log_in(@topic_contact)
    topic = create_test_topic_with_attachments(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_by_complete_attachment_name
    log_in(@company_forum_contact)
    topic = create_test_topic_with_attachments(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_any_visibility_with_category_id_by_complete_attachment_name
    topic = create_test_topic_with_attachments(@default_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_logged_visibility_with_category_id_by_complete_attachment_name
    log_in(@topic_contact)
    topic = create_test_topic_with_attachments(@logged_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

  def test_topic_with_company_visibility_with_category_id_by_complete_attachment_name
    log_in(@company_forum_contact)
    topic = create_test_topic_with_attachments(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

end