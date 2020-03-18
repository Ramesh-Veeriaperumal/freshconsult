require_relative '../../../../api/unit_test_helper'
['forum_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }

class Support::SearchV2::SpotlightControllerTest < ActionController::TestCase
  include ForumHelper
  def setup
    Account.stubs(:current).returns(Account.first)
    @account = Account.current
  end

  def test_construct_es_query_with_forum_ids_param
    forum_category = create_test_category
    test_forum1 = create_test_forum(forum_category)
    test_forum2 = create_test_forum(forum_category)
    test_forum3 = create_test_forum(forum_category)
    @controller.params = { forum_ids: "#{test_forum1.id},#{test_forum2.id},#{test_forum3.id}" }
    query = @controller.safe_send('search_forums_with_ids', forum_category.id)
    expected_query = "forum_id:#{test_forum1.id} OR forum_id:#{test_forum2.id} OR forum_id:#{test_forum3.id}"
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_category_ids_params
    forum_category1 = create_test_category
    forum_category2 = create_test_category
    @controller.params = { category_ids: "#{forum_category1.id},#{forum_category2.id}" }
    query = @controller.safe_send('search_forum_categories_with_ids', [forum_category1.id, forum_category2.id])
    expected_query = [forum_category1.id, forum_category2.id]
    assert_equal expected_query, query
  end
end
