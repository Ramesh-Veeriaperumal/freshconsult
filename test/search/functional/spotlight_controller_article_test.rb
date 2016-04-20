require_relative '../test_helper'

class Search::V2::SpotlightControllerTest < ActionController::TestCase

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