# frozen_string_literal: true

require_relative '../../../../../api/api_test_helper'
['forum_helper.rb', 'solutions_helper.rb', 'solution_builder_helper.rb', 'user_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
['search_test_helper.rb', 'archive_ticket_test_helper.rb'].each { |file| require "#{Rails.root}/test/api/helpers/#{file}" }
require_relative '../../../../../core/helpers/tickets_test_helper'

class Support::SearchV2::SpotlightControllerTest < ActionDispatch::IntegrationTest
  include ForumHelper
  include SolutionsHelper
  include SolutionBuilderHelper
  include SearchTestHelper
  include CoreTicketsTestHelper
  include ArchiveTicketTestHelper
  include UsersHelper

  ARCHIVE_DAYS = 120

  def setup
    super
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
  end

  def test_article_search_data_without_login_with_feature
    user = add_new_user(Account.current, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    Account.any_instance.stubs(:features?).returns(true)
    reset_request_headers
    account_wrap do
      stub_private_search_response([article]) do
        get '/support/search/solutions', version: :private, term: article.title
      end
    end
    assert response.body.include? "/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_article_search_data_without_login_without_feature
    user = add_new_user(Account.current, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    reset_request_headers
    account_wrap do
      stub_private_search_response([article]) do
        get '/support/search/solutions', version: :private, term: article.title
      end
    end
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_article_search_data_with_user_login
    user = add_new_user(Account.current, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([article]) do
        get '/support/search/solutions', version: :private, term: article.title
      end
    end
    assert response.body.include?("/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"), 'It is not matched'
  end

  def test_article_search_data_with_user_login_as_json
    user = add_new_user(Account.current, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([article]) do
        get '/support/search/solutions', version: :private, term: article.title, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], "/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"
    assert_equal res_body['type'], 'ARTICLE'
  end

  def test_article_search_data_with_user_login_as_json_with_filters
    user = add_new_user(Account.current, active: true)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    set_request_auth_headers(user)
    Account.any_instance.stubs(:has_feature?).returns(true)
    account_wrap(user) do
      stub_private_search_response([article]) do
        get '/support/search/solutions', version: :private, term: article.title, category_ids: article_meta.solution_category_meta.id.to_s, folder_ids: article_meta.solution_folder_meta.id.to_s, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], "/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"
    assert_equal res_body['type'], 'ARTICLE'
  ensure
    Account.any_instance.unstub(:has_feature?)
  end

  def test_tickets_search_data_without_login
    ticket = create_ticket
    reset_request_headers
    account_wrap do
      stub_private_search_response([ticket]) do
        get '/support/search/tickets', version: :private, term: ticket.subject
      end
    end
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  end

  def test_tickets_search_data_with_user_login
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([ticket]) do
        get '/support/search/tickets', version: :private, term: ticket.subject
      end
    end
    assert response.body.include? "/support/tickets/#{ticket.display_id}"
  end

  def test_tickets_search_data_with_user_login_as_json
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([ticket]) do
        get '/support/search/tickets', version: :private, term: ticket.subject, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], "/support/tickets/#{ticket.display_id}"
    assert_equal res_body['type'], 'TICKET'
  end

  def test_tickets_search_data_with_user_login_as_json_with_count
    user = add_new_user(Account.current, active: true)
    ticket = create_ticket(requester_id: user.id)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([ticket]) do
        get '/support/search/tickets', version: :private, term: ticket.subject, need_count: true, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal res_body['item'][0]['url'], "/support/tickets/#{ticket.display_id}"
    assert_equal res_body['item'][0]['type'], 'TICKET'
    assert_equal res_body['count'], 1
  end

  def test_archive_tickets_search_data_with_user_login
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    user = add_new_user(Account.current, active: true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([@account.archive_tickets.where(display_id: @archive_ticket.display_id).last]) do
        get '/support/search/tickets', version: :private, term: @archive_ticket.subject
      end
    end
    assert response.body.include? support_archive_ticket_path(@archive_ticket.display_id)
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    cleanup_archive_ticket(@archive_ticket, conversations: true)
  end

  def test_archive_tickets_search_data_with_user_login_as_json
    @account.enable_ticket_archiving(ARCHIVE_DAYS)
    @account.features.send(:archive_tickets).create
    create_archive_ticket_with_assoc(created_at: 150.days.ago, updated_at: 150.days.ago, create_association: true)
    user = add_new_user(Account.current, active: true)
    Helpdesk::ArchiveTicket.any_instance.stubs(:read_from_s3).returns(@archive_association)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([@account.archive_tickets.where(display_id: @archive_ticket.display_id).last]) do
        get '/support/search/tickets', version: :private, term: @archive_ticket.subject, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], support_archive_ticket_path(@archive_ticket.display_id)
    assert_equal res_body['type'], 'ARCHIVED TICKET'
  ensure
    Helpdesk::ArchiveTicket.any_instance.unstub(:read_from_s3)
    cleanup_archive_ticket(@archive_ticket, conversations: true)
  end

  def test_topic_search_data_without_login_with_feature
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:hide_portal_forums).returns(false)
    reset_request_headers
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics', version: :private, term: 'test'
      end
    end
    assert response.body.include? support_discussions_topic_path(topic)
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_topics_search_data_without_login_without_feature
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_forums).returns(false)
    reset_request_headers
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics', version: :private, term: 'test'
      end
    end
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_topics_search_data_with_user_login
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:hide_portal_forums).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics', version: :private, term: 'test'
      end
    end
    assert response.body.include?(support_discussions_topic_path(topic)), "failed :: #{response.body.inspect} #{support_discussions_topic_path(topic).inspect}  #{support_discussions_topic_path(topic.id).inspect}"
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_topics_search_data_with_user_login_as_json
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:hide_portal_forums).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics', version: :private, term: 'test', format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], support_discussions_topic_path(topic)
    assert_equal res_body['type'], 'TOPIC'
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_topics_search_data_with_user_login_as_json_with_filters
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:hide_portal_forums).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics', version: :private, term: 'test', forum_category_ids: forum_category.id.to_d, forum_ids: forum.id.to_s, format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)[0]
    assert_equal res_body['url'], support_discussions_topic_path(topic)
    assert_equal res_body['type'], 'TOPIC'
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_all_search_data_without_login_without_feature
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:open_forums).returns(false)
    Account.any_instance.stubs(:features?).with(:open_solutions).returns(false)
    Account.any_instance.stubs(:features?).with(:enable_multilingual).returns(false)
    reset_request_headers
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search', version: :private, term: 'test'
      end
    end
    assert_redirected_to send(Helpdesk::ACCESS_DENIED_ROUTE)
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_all_search_data_without_login_with_feature
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:enable_multilingual).returns(false)
    reset_request_headers
    account_wrap(user) do
      stub_private_search_response([topic, article]) do
        get '/support/search', version: :private, term: 'test'
      end
    end
    assert response.body.include?("/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"), 'failed test'
    assert response.body.include?(support_discussions_topic_path(topic)), "failed :: #{response.body.inspect} #{support_discussions_topic_path(topic).inspect}  #{support_discussions_topic_path(topic.id).inspect}"
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_all_search_data_with_user_login
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    ticket = create_ticket(requester_id: user.id)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:enable_multilingual).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic, article, ticket]) do
        get '/support/search', version: :private, term: 'test'
      end
    end
    assert response.body.include?("/support/tickets/#{ticket.display_id}"), "Failed :: #{response.body} #{ticket}"
    assert response.body.include?("/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"), 'Failed'
    assert response.body.include?(support_discussions_topic_path(topic)), "Failed :: #{response.body}    #{support_discussions_topic_path(topic).inspect}"
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_all_search_data_with_user_login_as_json
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    article_meta = create_article(article_params.merge(user_id: user.id))
    article = article_meta.primary_article
    ticket = create_ticket(requester_id: user.id)
    Account.any_instance.stubs(:features?).returns(true)
    Account.any_instance.stubs(:features?).with(:enable_multilingual).returns(false)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic, article, ticket]) do
        get '/support/search', version: :private, term: 'test', format: 'json'
      end
    end
    assert_response 200
    res_body = JSON.parse(response.body)
    assert_equal res_body[0]['url'], support_discussions_topic_path(topic)
    assert_equal res_body[1]['url'], "/support/solutions/articles/#{article_meta.id}-#{article.title.parameterize}"
    assert_equal res_body[2]['url'], "/support/tickets/#{ticket.display_id}"
  ensure
    Account.any_instance.unstub(:features?)
  end

  def test_suggest_topic_search_data_with_user_login
    forum_category = create_test_category
    forum = create_test_forum(forum_category)
    user = add_new_user(Account.current, active: true)
    topic = create_test_topic(forum, user)
    set_request_auth_headers(user)
    account_wrap(user) do
      stub_private_search_response([topic]) do
        get '/support/search/topics/suggest', version: :private, term: 'test'
      end
    end
    assert response.body.include? support_discussions_topic_path(topic)
  end

  private

    def article_params(folder_visibility = Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone])
      category = create_category
      {
        title: 'Test',
        description: 'Test',
        folder_id: create_folder(visibility: folder_visibility, category_id: category.id).id
      }
    end

    def old_ui?
      true
    end
end
