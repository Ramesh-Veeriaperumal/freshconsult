require_relative '../test_helper'

class Search::V2::MergeTopicsControllerTest < ActionController::TestCase

  def test_locked_topic_by_title
    topic = create_test_topic(@account.forums.first, @agent)
    lock_topic(topic)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :search_topics, :term => topic.title

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, topic.id
  end

  def test_locked_topic_by_post_content
    topic = create_test_topic(@account.forums.first, @agent)
    lock_topic(topic)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    get :search_topics, :term => topic.posts.first.body

    res_body = parsed_attr(response.body, 'id')
    assert_not_includes res_body, topic.id
  end

end