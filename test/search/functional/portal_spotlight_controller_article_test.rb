require_relative '../test_helper'

class Support::SearchV2::SpotlightControllerTest < ActionController::TestCase

  def setup
    super
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
    @company_contact = FactoryGirl.build(:user, :account => @account, 
                                                :email => Faker::Internet.email, 
                                                :user_role => 3,
                                                :privileges => Role.privileges_mask([:client_manager]),
                                                :customer_id => @company_folder.customer_ids.first)
  end

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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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

end