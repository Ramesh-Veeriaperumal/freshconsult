require_relative '../../api/unit_test_helper'

class ArticleFilterDummyController < ApiApplicationController
  include Solution::ArticleFilters
end

class ArticleFilterDummyControllerTest < ActionController::TestCase
  def test_construct_es_query_with_empty_params
    @controller.params = {}
    query = @controller.safe_send('construct_es_query')
    assert_equal '', query
  end

  def test_construct_es_query_with_draft_status
    @controller.params = { status: 1 }
    query = @controller.safe_send('construct_es_query')
    expected_query = '(-draft_status:0)'
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_published_status
    @controller.params = { status: 2 }
    query = @controller.safe_send('construct_es_query')
    expected_query = '(status:2)'
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_draft_status_and_author
    @controller.params = { status: 1, author: 1 }
    query = @controller.safe_send('construct_es_query')
    expected_query = '(-draft_status:0) AND (user_id:1 OR draft_modified_by:1)'
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_published_status_and_author
    @controller.params = { status: 2, author: 1 }
    query = @controller.safe_send('construct_es_query')
    expected_query = '(status:2) AND (user_id:1 OR draft_modified_by:1 OR modified_by:1)'
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_single_folder
    @controller.params = { folder: [1] }
    query = @controller.safe_send('construct_es_query')
    expected_query = '(folder_id:1)'
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_draft_status_all_params
    @controller.params = { status: 1,
                           author: 1,
                           created_at: { start: '1989-11-23T16:30:00.000Z', end: '2010-11-09T18:30:00.000Z' },
                           last_modified: { start: '2018-11-08T19:30:00.000Z', end: '2019-11-09T20:30:00.000Z' },
                           outdated: true,
                           folder: [1, 2, 3] }
    query = @controller.safe_send('construct_es_query')
    expected_query = "(-draft_status:0) AND (user_id:1 OR draft_modified_by:1) AND (created_at:>'1989-11-23T16:30:00Z' AND created_at:<'2010-11-09T18:30:00Z') AND ((modified_at:>'2018-11-08T19:30:00Z' AND modified_at:<'2019-11-09T20:30:00Z') OR (draft_modified_at:>'2018-11-08T19:30:00Z' AND draft_modified_at:<'2019-11-09T20:30:00Z')) AND (outdated:true) AND (folder_id:1 OR folder_id:2 OR folder_id:3)"
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_published_status_all_params
    @controller.params = { status: 2,
                           author: 1,
                           created_at: { start: '1989-11-23T16:30:00.000Z', end: '2010-11-09T18:30:00.000Z' },
                           last_modified: { start: '2018-11-08T19:30:00.000Z', end: '2019-11-09T20:30:00.000Z' },
                           outdated: true,
                           folder: [1, 2, 3] }
    query = @controller.safe_send('construct_es_query')
    expected_query = "(status:2) AND (user_id:1 OR draft_modified_by:1 OR modified_by:1) AND (created_at:>'1989-11-23T16:30:00Z' AND created_at:<'2010-11-09T18:30:00Z') AND ((modified_at:>'2018-11-08T19:30:00Z' AND modified_at:<'2019-11-09T20:30:00Z') OR (draft_modified_at:>'2018-11-08T19:30:00Z' AND draft_modified_at:<'2019-11-09T20:30:00Z')) AND (outdated:true) AND (folder_id:1 OR folder_id:2 OR folder_id:3)"
    assert_equal expected_query, query
  end

  def test_construct_es_query_with_in_review_status_all_params
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    @controller.params = { status: 4,
                           author: 1,
                           created_at: { start: '1989-11-23T16:30:00.000Z', end: '2010-11-09T18:30:00.000Z' },
                           last_modified: { start: '2018-11-08T19:30:00.000Z', end: '2019-11-09T20:30:00.000Z' },
                           outdated: true,
                           folder: [1, 2, 3] }
    query = @controller.safe_send('construct_es_query')
    expected_query = "(draft_status:1) AND (user_id:1 OR draft_modified_by:1 OR modified_by:1) AND (created_at:>'1989-11-23T16:30:00Z' AND created_at:<'2010-11-09T18:30:00Z') AND ((modified_at:>'2018-11-08T19:30:00Z' AND modified_at:<'2019-11-09T20:30:00Z') OR (draft_modified_at:>'2018-11-08T19:30:00Z' AND draft_modified_at:<'2019-11-09T20:30:00Z')) AND (outdated:true) AND (folder_id:1 OR folder_id:2 OR folder_id:3)"
    assert_equal expected_query, query
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end

  def test_construct_es_query_with_approved_status_all_params
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    @controller.params = { status: 5,
                           author: 1,
                           created_at: { start: '1989-11-23T16:30:00.000Z', end: '2010-11-09T18:30:00.000Z' },
                           last_modified: { start: '2018-11-08T19:30:00.000Z', end: '2019-11-09T20:30:00.000Z' },
                           outdated: true,
                           folder: [1, 2, 3] }
    query = @controller.safe_send('construct_es_query')
    expected_query = "(draft_status:2) AND (user_id:1 OR draft_modified_by:1 OR modified_by:1) AND (created_at:>'1989-11-23T16:30:00Z' AND created_at:<'2010-11-09T18:30:00Z') AND ((modified_at:>'2018-11-08T19:30:00Z' AND modified_at:<'2019-11-09T20:30:00Z') OR (draft_modified_at:>'2018-11-08T19:30:00Z' AND draft_modified_at:<'2019-11-09T20:30:00Z')) AND (outdated:true) AND (folder_id:1 OR folder_id:2 OR folder_id:3)"
    assert_equal expected_query, query
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end
end
