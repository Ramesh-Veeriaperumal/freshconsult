require_relative '../../test_helper'
['solutions_approvals_test_helper.rb', 'solutions_test_helper.rb'].each { |file| require Rails.root.join('test', 'api', 'helpers', file) }

class ArticleTest < ActiveSupport::TestCase
  include ModelsSolutionsTestHelper
  include ModelsUsersTestHelper
  include SolutionsApprovalsTestHelper
  include SolutionsTestHelper

  def setup
    super
    @account = Account.first
    Account.stubs(:current).returns(@account)
    setup_multilingual
    $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', Faker::Lorem.word)
    $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', Faker::Lorem.word)
    $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', Faker::Lorem.word)
  end

  def test_central_publish_payload
    article = create_article(article_params).primary_article
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
  end

  def test_central_publish_article_payload_on_publish
    article = create_article(article_params).primary_article
    prev_published_by = article.modified_by
    prev_published_at = article.modified_at
    curr_published_by = 10101
    curr_published_at = Time.now
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.modified_by = curr_published_by
    article.modified_at = curr_published_at
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal [prev_published_at.try(:iso8601), article.modified_at.try(:iso8601)], model_changes['published_at']
    assert_equal [prev_published_by, curr_published_by], model_changes['published_by']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_published_by_change
    article = create_article(article_params).primary_article
    prev_published_at = article.modified_at
    curr_published_at = Time.now
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.modified_at = curr_published_at
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal [prev_published_at.try(:iso8601), article.modified_at.try(:iso8601)], model_changes['published_at']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_author_change
    article = create_article(article_params).primary_article
    old_author_id = article.user_id
    new_author_id = add_test_agent.id
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.user_id = new_author_id
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal [old_author_id, new_author_id], model_changes['agent_id']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_draft_create
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    draft = article.build_draft_from_article
    draft.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal [0, 1], model_changes['draft_exists']
    assert_equal [nil, draft.modified_at.try(:iso8601)], model_changes['draft_modified_at']
    assert_equal [nil, draft.modified_by], model_changes['draft_modified_by']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_draft_update
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    prev_modified_at = draft.modified_at
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    draft.title = 'random title'
    draft.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal [prev_modified_at.try(:iso8601), draft.modified_at.try(:iso8601)], model_changes['draft_modified_at']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_draft_delete
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    draft.destroy
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [1, 0], model_changes['draft_exists']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_approval_in_review_create
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    approval = construct_approval_record(article, User.current)
    construct_approver_mapping(approval, User.current)
    approval.save
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [nil, 1], model_changes['approval_status']
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_approval_in_review_to_approved
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    approval = construct_approval_record(article, User.current)
    construct_approver_mapping(approval, User.current)
    approval.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    approval.approval_status = 2
    approval.approver_mappings.first.approver_id = 10
    approval.save
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [1, 2], model_changes['approval_status']
    assert_equal [nil, approval.updated_at.try(:iso8601)], model_changes['approved_at']
    assert_equal [nil, approval.approver_mappings.first.approver_id], model_changes['approved_by']
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_approval_deleted
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    approval = construct_approval_record(article, User.current)
    construct_approver_mapping(approval, User.current)
    approval.save
    article.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    approval.destroy
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [1, nil], model_changes['approval_status']
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_publish_article_approval_deleted
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    approval = construct_approval_record(article, User.current)
    approver_mapping = construct_approver_mapping(approval, User.current)
    approval.approval_status = 2
    approval.approver_mappings.first.approver_id = 10
    approval.save
    article.save
    article.reload
    approved_by = approval.approved_by
    approved_at = approval.approved_at
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.draft.publish!
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [2, nil], model_changes['approval_status']
    assert_equal [approved_by, nil], model_changes['approved_by']
    assert_equal [approved_at.try(:iso8601), nil], model_changes['approved_at']
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_approved_article_deleted
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    article = create_article(article_params).primary_article
    draft = article.build_draft_from_article
    draft.save
    approval = construct_approval_record(article, User.current)
    construct_approver_mapping(approval, User.current)
    approval.save
    article.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.destroy
    job = CentralPublishWorker::SolutionArticleWorker.jobs.first
    assert_equal 'article_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_article_destroy_pattern(article))
  ensure
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end

  def test_central_publish_article_payload_on_publishing
    article = create_article(article_params).primary_article
    prev_published_by = article.modified_by
    prev_published_at = article.modified_at
    draft = article.build_draft_from_article
    draft.save
    article.reload
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.draft.publish!
    job = CentralPublishWorker::SolutionArticleWorker.jobs.first
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal nil, model_changes['status']
    assert_equal [prev_published_at.try(:iso8601), article.modified_at.try(:iso8601)], model_changes['published_at']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_article_payload_on_publishing_draft
    article = create_article(article_params(status: 1)).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.draft.publish!
    job = CentralPublishWorker::SolutionArticleWorker.jobs.first
    article.reload
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    assert_equal 'article_update', job['args'][0]
    model_changes = job['args'][1]['model_changes']
    assert_equal 'solution_articles', job['args'][1]['relationship_with_account']
    assert_equal [1, 2], model_changes['status']
    assert_equal [nil, article.modified_by], model_changes['published_by']
    assert_equal [nil, article.modified_at.try(:iso8601)], model_changes['published_at']
  ensure
    article.try(:destroy)
  end

  def test_central_publish_payload_update_title
    article = create_article(article_params).primary_article
    old_title = article.title
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.reload
    article.title = new_title = Faker::Lorem.word
    article.save
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_update', job['args'][0]
    assert_equal({ 'title' => [old_title, new_title] }, job['args'][1]['model_changes'].slice('title'))
  end

  def test_central_publish_payload_thumbs_up_non_logged_in
    article = create_article(article_params).primary_article
    User.stubs(:current).returns(nil)
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.thumbs_up!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_up'))
  ensure
    User.unstub(:current)
  end

  def test_central_publish_payload_thumbs_up_logged_in
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.thumbs_up!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_up'))
  end

  def test_central_publish_payload_thumbs_up_secondary_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    primary_article = article_meta.primary_article
    10.times do
      primary_article.thumbs_up!
    end
    translated_article = article_meta.safe_send("#{language}_article")
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    translated_article.set_portal_interaction_source
    translated_article.thumbs_up!
    translated_article.central_payload_type = :article_interactions
    payload = translated_article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(translated_article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [10, 11] }, job['args'][1]['model_changes'].slice('thumbs_up'))
  end

  def test_central_publish_payload_thumbs_up_secondary_portal
    article = create_article(article_params).primary_article
    secondary_portal = create_portal
    secondary_portal.solution_category_metum_ids = secondary_portal.solution_category_metum_ids | @account.solution_category_meta.map(&:id)
    Portal.stubs(:current).returns(secondary_portal)
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.thumbs_up!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    event_info = article.event_info(:interactions)
    event_info.must_match_json_expression(central_publish_article_interactions_event_info)
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_up'))
  ensure
    Portal.unstub(:current)
  end

  def test_central_publish_payload_thumbs_down_non_logged_in
    article = create_article(article_params).primary_article
    User.stubs(:current).returns(nil)
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.thumbs_down!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  ensure
    User.unstub(:current)
  end

  def test_central_publish_payload_thumbs_down_logged_in
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.thumbs_down!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  end

  def test_central_publish_payload_reset_ratings
    article = create_article(article_params).primary_article
    10.times do
      article.thumbs_up!
    end
    5.times do
      article.thumbs_down!
    end
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.reset_ratings
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [10, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [10, 0] }, job['args'][1]['model_changes'].slice('thumbs_up'))
    assert_equal({ 'article_thumbs_down' => [5, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [5, 0] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  end

  def test_central_publish_payload_reset_ratings_secondary_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    primary_article = article_meta.primary_article
    10.times do
      primary_article.thumbs_up!
    end
    5.times do
      primary_article.thumbs_down!
    end
    translated_article = article_meta.safe_send("#{language}_article")
    6.times do
      translated_article.thumbs_up!
    end
    3.times do
      translated_article.thumbs_down!
    end
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    translated_article.reset_ratings
    translated_article.central_payload_type = :article_interactions
    payload = translated_article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(translated_article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [6, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [16, 10] }, job['args'][1]['model_changes'].slice('thumbs_up'))
    assert_equal({ 'article_thumbs_down' => [3, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [8, 5] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  end

  def test_central_publish_payload_hits
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.hit!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_hits' => [0, 1] }, job['args'][1]['model_changes'].slice('article_hits'))
    assert_equal({ 'hits' => [0, 1] }, job['args'][1]['model_changes'].slice('hits'))
  end

  def test_central_publish_payload_hits_secondary_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    primary_article = article_meta.primary_article
    10.times do
      primary_article.hit!
    end
    translated_article = article_meta.safe_send("#{language}_article")
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    translated_article.set_portal_interaction_source
    translated_article.hit!
    translated_article.central_payload_type = :article_interactions
    payload = translated_article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(translated_article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_hits' => [0, 1] }, job['args'][1]['model_changes'].slice('article_hits'))
    assert_equal({ 'hits' => [10, 11] }, job['args'][1]['model_changes'].slice('hits'))
  end

  def test_central_publish_payload_toggle_thumbs_up
    # Happens only if logged in
    article = create_article(article_params).primary_article
    article.thumbs_down!
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.toggle_thumbs_up!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_up'))
    assert_equal({ 'article_thumbs_down' => [1, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [1, 0] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  end

  def test_central_publish_payload_toggle_thumbs_down
    # Happens only if logged in
    article = create_article(article_params).primary_article
    article.thumbs_up!
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.set_portal_interaction_source
    article.toggle_thumbs_down!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_thumbs_up' => [1, 0] }, job['args'][1]['model_changes'].slice('article_thumbs_up'))
    assert_equal({ 'thumbs_up' => [1, 0] }, job['args'][1]['model_changes'].slice('thumbs_up'))
    assert_equal({ 'article_thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('article_thumbs_down'))
    assert_equal({ 'thumbs_down' => [0, 1] }, job['args'][1]['model_changes'].slice('thumbs_down'))
  end

  def test_central_publish_payload_suggested
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.suggested!
    article.central_payload_type = :article_interactions
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_suggested' => [0, 1] }, job['args'][1]['model_changes'].slice('article_suggested'))
  end

  def test_central_publish_payload_suggested_secondary_language
    languages = @account.supported_languages + ['primary']
    language = @account.supported_languages.first
    article_meta = create_article(article_params(lang_codes: languages))
    translated_article = article_meta.safe_send("#{language}_article")
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    translated_article.suggested!
    translated_article.central_payload_type = :article_interactions
    payload = translated_article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_interactions_pattern(translated_article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_interactions', job['args'][0]
    assert_equal({ 'article_suggested' => [0, 1] }, job['args'][1]['model_changes'].slice('article_suggested'))
  end

  def test_ml_training_payload
    article = create_article(article_params).primary_article
    article.central_payload_type = :ml_training
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
  end

  def test_central_publish_destroy_payload
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.destroy
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal CentralPublishWorker::SolutionArticleWorker.jobs.size, 1
    assert_equal 'article_destroy', job['args'][0]
    assert_equal({}, job['args'][1]['model_changes'])
    job['args'][1]['model_properties'].must_match_json_expression(central_publish_article_destroy_pattern(article))
  end

  def test_central_publish_tags_payload
    article = create_article(article_params).primary_article
    tag1 = create_tag(@account, name: "#{Faker::Lorem.characters(7)}#{rand(999_999)}")
    tag2 = create_tag(@account, name: "#{Faker::Lorem.characters(7)}#{rand(999_999)}")
    tag3 = create_tag(@account, name: "#{Faker::Lorem.characters(7)}#{rand(999_999)}")
    article.add_tag_activity(tag1)
    article.add_tag_activity(tag2)
    article.save
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.remove_tag_activity(tag2)
    article.add_tag_activity(tag3)
    article.save
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal CentralPublishWorker::SolutionArticleWorker.jobs.size, 1
    assert_equal 'article_update', job['args'][0]
    job['args'][1]['model_changes']['tags'].must_match_json_expression(central_publish_article_tags_pattern(article))
  end

  def test_central_publish_payload_update_author
    article = create_article(article_params).primary_article
    old_author = @account.users.find(article.user_id)
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.reload
    new_author = add_test_agent
    article.user_id = new_author.id
    article.save
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_update', job['args'][0]
    assert_equal CentralPublishWorker::SolutionArticleWorker.jobs.size, 1
    assert_equal({ 'agent_name' => [old_author.name, new_author.name] }, job['args'][1]['misc_changes'].slice('agent_name'))
  end

  def test_central_publish_payload_update_folder
    article = create_article(article_params).primary_article
    old_folder = @account.solution_folders.where(parent_id: article.parent.solution_folder_meta_id, language_id: article.language_id).first
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.reload
    new_folder = create_folder(folder_params)
    article.parent.solution_folder_meta_id = new_folder.id
    article.parent.save
    article.save
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_update', job['args'][0]
    assert_equal CentralPublishWorker::SolutionArticleWorker.jobs.size, 1
    assert_equal({ 'solution_folder_name' => [old_folder.name, new_folder.name] }, job['args'][1]['misc_changes'].slice('solution_folder_name'))
  end

  def test_central_publish_payload_for_unpublish_event
    article = create_article(article_params).primary_article
    CentralPublishWorker::SolutionArticleWorker.jobs.clear
    article.status = 1
    article.save
    payload = article.central_publish_payload.to_json
    payload.must_match_json_expression(central_publish_article_pattern(article))
    job = CentralPublishWorker::SolutionArticleWorker.jobs.last
    assert_equal 'article_update', job['args'][0]
    assert_equal job['args'][1]['model_changes']['status'], [2, 1]
  end

  def article_params(options = {})
    lang_hash = { lang_codes: options[:lang_codes] }
    category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
    {
      title: 'Test',
      description: 'Test',
      folder_id: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id,
      status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
    }.merge(lang_hash)
  end

  def folder_params(options = {})
    lang_hash = { lang_codes: options[:lang_codes] }
    category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
    { visibility: options[:visibility] || Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)
  end
end
