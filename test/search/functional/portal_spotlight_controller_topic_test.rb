require_relative '../test_helper'

class Support::SearchV2::SpotlightControllerTest < ActionController::TestCase

  def setup
    super
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
    @company_contact = FactoryGirl.build(:user, :account => @account, 
                                                :email => Faker::Internet.email, 
                                                :user_role => 3,
                                                :privileges => Role.privileges_mask([:client_manager]),
                                                :customer_id => @company_forum.customer_forums.pluck(:customer_id).first)
  end

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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
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
    log_in(@company_contact)
    topic = create_test_topic_with_attachments(@company_forum, @agent)
    sleep Searchv2::SearchHelper::ES_DELAY_TIME # Delaying for sidekiq to send to ES
    
    xhr :get, :topics, term: topic.posts.first.attachments.first.content_file_name.split('.').first, category_id: topic.forum.forum_category_id

    res_body = parsed_support_attr(response.body, 'url')
    assert_includes res_body, "/support/discussions/topics/#{topic.id}"
  end

end