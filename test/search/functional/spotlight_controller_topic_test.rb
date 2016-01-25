require_relative '../test_helper'

class Search::V2::SpotlightControllerTest < ActionController::TestCase

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
    
    get :forums, term: topic.posts.first.attachments.first.content_file_name.split('.').first

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

  def test_topic_with_category_id_by_complete_attachment_name
    topic = create_test_topic_with_attachments(@account.forums.first, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :forums, term: topic.posts.first.attachments.first.content_file_name.split('.').first, category_id: topic.forum_category_id

    res_body = parsed_attr(response.body, 'id')
    assert_includes res_body, topic.id
  end

end