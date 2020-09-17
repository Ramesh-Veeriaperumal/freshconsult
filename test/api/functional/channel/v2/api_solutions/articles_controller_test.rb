require_relative '../../../../test_helper'
require Rails.root.join('test', 'models', 'helpers', 'tag_use_test_helper.rb')
class Channel::V2::ApiSolutions::ArticlesControllerTest < ActionController::TestCase
  include JweTestHelper
  include SolutionsTestHelper
  include SolutionsArticlesTestHelper
  include CoreSolutionsTestHelper
  include SolutionsPlatformsTestHelper
  include TagUseTestHelper
  include SearchTestHelper
  SUPPORT_BOT = 'frankbot'.freeze
  FRESHCONNECT_SRC = 'freshconnect'.freeze
  KBSERVICE = 'kbservice'.freeze

  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    Account.stubs(:current).returns(@account)
    setup_multilingual(['es', 'ru-RU'])
    return if @@initial_setup_run
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @account.reload
    setup_articles
    @@initial_setup_run = true
  end

  def setup_articles
    @category_meta = Solution::CategoryMeta.last

    @category = Solution::Category.new
    @category.name = 'test category'
    @category.description = 'test description'
    @category.account = @account
    @category.language_id = Language.find_by_code('en').id
    @category.parent_id = @category_meta.id
    @category.save

    @folder_meta = Solution::FolderMeta.new
    @folder_meta.visibility = 1
    @folder_meta.solution_category_meta = @category_meta
    @folder_meta.account = @account
    @folder_meta.save

    @folder = Solution::Folder.new
    @folder.name = 'test folder'
    @folder.description = 'test description'
    @folder.account = @account
    @folder.parent_id = @folder_meta.id
    @folder.language_id = Language.find_by_code('en').id
    @folder.save

    @articlemeta = Solution::ArticleMeta.new
    @articlemeta.art_type = 1
    @articlemeta.solution_folder_meta_id = @folder_meta.id
    @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
    @articlemeta.account_id = @account.id
    @articlemeta.published = false
    @articlemeta.save

    @article = Solution::Article.new
    @article.title = 'Sample'
    @article.description = '<b>aaa</b>'
    @article.status = 2
    @article.language_id = @account.language_object.id
    @article.parent_id = @articlemeta.id
    @article.account_id = @account.id
    @article.user_id = @account.agents.first.id
    @article.save

    @draft = Solution::Draft.new
    @draft.account = @account
    @draft.article = @article
    @draft.title = 'Sample'
    @draft.category_meta = @article.solution_folder_meta.solution_category_meta
    @draft.status = 1
    @draft.description = '<b>aaa</b>'
    @draft.save

    temp_article_meta = Solution::ArticleMeta.new
    temp_article_meta.art_type = 1
    temp_article_meta.solution_folder_meta_id = @folder_meta.id
    temp_article_meta.solution_category_meta = @folder_meta.solution_category_meta
    temp_article_meta.account_id = @account.id
    temp_article_meta.published = false
    temp_article_meta.save

    temp_article = Solution::Article.new
    temp_article.title = 'Sample article without draft'
    temp_article.description = '<b>Test</b>'
    temp_article.status = 2
    temp_article.language_id = @account.language_object.id
    temp_article.parent_id = temp_article_meta.id
    temp_article.account_id = @account.id
    temp_article.user_id = @account.agents.first.id
    temp_article.save

    @draft_body = Solution::DraftBody.new
    @draft_body.draft = @draft
    @draft_body.description = '<b>aaa</b>'
    @draft_body.account = @account
    @draft_body.save

    @category = Solution::Category.new
    @category.name = 'test lang category'
    @category.description = 'test description'
    @category.account = @account
    @category.parent_id = @category_meta.id
    @category.language_id = Language.find_by_code('ru-RU').id
    @category.save

    @folder = Solution::Folder.new
    @folder.name = 'test lang folder'
    @folder.description = 'test description'
    @folder.account = @account
    @folder.parent_id = @folder_meta.id
    @folder.language_id = Language.find_by_code('ru-RU').id
    @folder.save

    @article_with_lang = Solution::Article.new
    @article_with_lang.title = 'Sample lang'
    @article_with_lang.description = '<b>aaa</b>'
    @article_with_lang.status = 1
    @article_with_lang.language_id = Language.find_by_code('ru-RU').id
    @article_with_lang.parent_id = @articlemeta.id
    @article_with_lang.account_id = @account.id
    @article_with_lang.user_id = @account.agents.first.id
    @article_with_lang.save
  end

  def wrap_cname(params)
    { article: params }
  end

  def test_show_article_support_bot_source
    @enrich_response = true
    set_jwe_auth_header(SUPPORT_BOT)
    sample_article = get_article
    get :show, controller_params(id: sample_article.parent_id)
    assert_response 200
  end

  def test_show_published_article_without_draft_freshconnect_source
    @enrich_response = true
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    sample_article = get_article_without_draft

    get :show, controller_params(id: sample_article.parent_id)

    match_json(channel_api_solution_article_pattern(sample_article))
    assert_response 200
  ensure
    CustomRequestStore.unstub(:read)
  end

  def test_show_published_article_multilingual_without_draft_freshconnect_source
    @enrich_response = true
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    sample_article = get_article_without_draft(language = Language.find_by_code('ru-RU'))

    get :show, controller_params(id: sample_article.parent_id, language: 'ru-RU')
    match_json(channel_api_solution_article_pattern(sample_article))
    assert_response 200
  ensure
    CustomRequestStore.unstub(:read)
  end

  def test_show_article_with_draft_freshconnect_source
    @enrich_response = true
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    sample_article = get_article_with_draft

    get :show, controller_params(id: sample_article.parent_id)

    match_json(channel_api_solution_article_pattern(sample_article))
    assert_response 200
  ensure
    CustomRequestStore.unstub(:read)
  end

  def test_show_article_with_approval_flow_freshconnect_source
    @enrich_response = true
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    sample_article = get_article_with_draft

    get :show, controller_params(id: sample_article.parent_id)

    match_json(channel_api_solution_article_pattern(sample_article))
    assert_response 200
  ensure
    CustomRequestStore.unstub(:read)
    Account.any_instance.unstub(:article_approval_workflow_enabled?)
  end

  def test_show_article_with_default_folder_category_freshconnect_source
    @enrich_response = true
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    sample_article = get_article_with_draft
    Solution::FolderMeta.any_instance.stubs(:is_default).returns(true)
    Solution::CategoryMeta.any_instance.stubs(:is_default).returns(true)

    get :show, controller_params(id: sample_article.parent_id)

    match_json(channel_api_solution_article_pattern(sample_article))
    assert_response 200
  ensure
    CustomRequestStore.unstub(:read)
    Solution::FolderMeta.any_instance.unstub(:is_default)
    Solution::CategoryMeta.any_instance.stubs(:is_default)
  end

  def test_show_article_only_published
    @enrich_response = true
    set_jwe_auth_header(SUPPORT_BOT)
    sample_article = get_article
    create_draft(article: sample_article)
    get :show, controller_params(id: sample_article.parent_id, prefer_published: true)
    assert_response 200
    assert_not_equal '<b>draft body</b>', JSON.parse(response.body)[:description]
  end

  def test_return_not_found_for_draft_article_with_status_published
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwe_auth_header(SUPPORT_BOT)
    article_meta = create_article(status: '1')
    article = article_meta.solution_articles.first
    create_draft(article: article)
    get :show, controller_params(id: article.parent_id, prefer_published: true, status: 2)
    assert_response 404
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_only_published_articles_returned_with_status
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwe_auth_header(SUPPORT_BOT)
    category_meta = create_category
    folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
    article_meta = create_article(folder_meta_id: folder_meta.id, status: '1')
    article = article_meta.solution_articles.first
    create_draft(article: article)
    get :folder_articles, controller_params(id: folder_meta.id, prefer_published: true, status: 2)
    assert_response 200
    assert_equal '[]', response.body
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_channeel_folder_articles_with_invalid_status
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    Account.current.launch(:kbase_omni_bundle)
    set_jwe_auth_header(SUPPORT_BOT)
    category_meta = create_category
    folder_meta = create_folder(visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category_meta.id)
    get :folder_articles, controller_params(id: folder_meta.id, prefer_published: true, status: '3')
    assert_response 400
    expected = { description: 'Validation failed', errors: [{ field: 'status', message: "It should be one of these values: '1,2'", code: 'invalid_value' }] }
    assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_language_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    translated_article = get_article(language = Language.find_by_code('ru-RU'))
    folder = translated_article.solution_folder_meta.solution_folders.where(language_id: Language.find_by_code('ru-RU').id).first
    get :folder_articles, controller_params(version: 'channel', id: folder.parent.id, language: 'ru-RU')
    assert_response 200
    articles = folder.parent.solution_articles.where(language_id: Language.find_by_code('ru-RU').id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[folder.parent.article_order]).limit(30)
    pattern = articles.map { |article| channel_api_solution_article_pattern(article) }
    match_json(pattern.ordered!)
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_portal_id_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    create_article_in_portal
    articles = get_articles_by_portal_id(@account.main_portal.id, @account.language_object.id)
    folder = articles.first.parent.solution_folder_meta.solution_folders.first
    get :folder_articles, controller_params(id: folder.parent.id, language: @account.language_object.code, portal_id: @account.main_portal.id)
    assert_response 200
    articles = articles.select { |article| article.parent.solution_folder_meta.solution_folders.where(language_id: article.language.id).first.id == folder.id }
    pattern = articles.map { |art| channel_api_solution_article_pattern(art) }
    match_json(pattern.ordered!)
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_platforms_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_new = get_article_with_platform_mapping(ios: true, web: true, android: false)
    folder_meta = article_new.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article_new.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, platforms: 'ios')
    assert_response 200
    articles = folder_meta.solution_articles.where(language_id: article_new.language.id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[folder_meta.article_order])
    articles_with_platforms = articles.select { |article| article.parent.solution_platform_mapping.present? && article.parent.solution_platform_mapping.enabled_platforms.include?('ios') }
    pattern = articles_with_platforms.map { |art| channel_api_solution_article_pattern(art) }
    match_json(pattern.ordered!)
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_allow_language_fallback_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_new = get_article_with_platform_mapping(ios: true, web: true, android: false)
    folder_meta = article_new.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article_new.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, allow_language_fallback: 'true')
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_tags_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_meta = create_article
    article = article_meta.solution_articles.first
    tag = Faker::Lorem.characters(7)
    create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag, allow_skip: true)
    folder_meta = article.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, tags: tag)
    assert_response 200
    articles = folder_meta.solution_articles.where(language_id: article.language.id).reorder(Solution::Constants::ARTICLE_ORDER_COLUMN_BY_TYPE[folder_meta.article_order])
    article_with_tags = articles.select { |arti| arti.tags.present? && arti.tags.collect(&:name).include?(tag) }
    pattern = article_with_tags.map { |art| channel_api_solution_article_pattern(art) }
    match_json(pattern.ordered!)
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_tags_null_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_meta = create_article
    article = article_meta.solution_articles.first
    tag = Faker::Lorem.characters(7)
    create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag, allow_skip: true)
    folder_meta = article.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, tags: '')
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern('tags', :comma_separated_values, prepend_msg: :input_received, given_data_type: DataTypeValidator::DATA_TYPE_MAPPING[NilClass], code: :invalid_value)))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_articles_with_platforms_null_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_new = get_article_with_platform_mapping(ios: true, web: true, android: false)
    folder_meta = article_new.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article_new.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, platforms: '')
    assert_response 400
    match_json(validation_error_pattern(bad_request_error_pattern('platforms', :comma_separated_values, prepend_msg: :input_received, given_data_type: DataTypeValidator::DATA_TYPE_MAPPING[NilClass], code: :invalid_value)))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_folder_index_with_platforms_with_omni_disabled
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    article_new = get_article_with_platform_mapping(ios: true, web: true, android: false)
    folder_meta = article_new.solution_folder_meta
    sample_folder = folder_meta.solution_folders.where(language_id: article_new.language.id).first
    get :folder_articles, controller_params(id: folder_meta.id, platforms: 'ios')
    assert_response 403
    match_json(validation_error_pattern(bad_request_error_pattern('platforms', :require_feature, feature: :omni_bundle_2020, code: :access_denied)))
  ensure
    CustomRequestStore.unstub(:read)
  end

  def test_invalid_allow_language_fallback_params
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    translated_article = get_article(language = Language.find_by_code('ru-RU'))
    folder = translated_article.solution_folder_meta.solution_folders.where(language_id: Language.find_by_code('ru-RU').id).first
    get :folder_articles, controller_params(version: 'channel', id: folder.parent.id, language: 'ru-RU', allow_language_fallback: 'invalid')
    assert_response 400
    expected = { description: 'Validation failed', errors: [{ field: 'allow_language_fallback', message: "Value set is of type String.It should be a/an Boolean", code: 'datatype_mismatch' }] }
    assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_article_hit_count
    stub_channel_api do
      Channel::V2::ApiSolutions::ArticlesController.any_instance.stubs(:agent?).returns(false)
      article_new = get_article_without_draft
      initial_views = @account.solution_articles.find(article_new.id).hits
      put :hit, controller_params(version: 'channel', id: article_new.id, source_type: 'freshchat')
      final_views = @account.solution_articles.find(article_new.id).hits
      assert_response 204
      assert_equal initial_views, final_views - 1
    end
    Channel::V2::ApiSolutions::ArticlesController.any_instance.unstub(:agent?)
  end

  def test_article_hit_with_agent_set
    stub_channel_api do
      Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(false)
      Channel::V2::ApiSolutions::ArticlesController.any_instance.stubs(:agent?).returns(true)
      article_new = get_article_without_draft
      initial_views = @account.solution_articles.find(article_new.id).hits
      put :hit, controller_params(version: 'channel', id: article_new.id, source_type: 'freshchat')
      final_views = @account.solution_articles.find(article_new.id).hits
      assert_response 204
      assert_equal initial_views, final_views
    end
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
    Channel::V2::ApiSolutions::ArticlesController.any_instance.unstub(:agent?)
  end

  def test_article_hit_with_solutions_agent_metrics_enabled
    stub_channel_api do
    Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
    Channel::V2::ApiSolutions::ArticlesController.any_instance.stubs(:agent?).returns(true)
    article_new = get_article_without_draft
    initial_views = @account.solution_articles.find(article_new.id).hits
    put :hit, controller_params(version: 'channel', id: article_new.id, source_type: 'freshchat')
    final_views = @account.solution_articles.find(article_new.id).hits
    assert_response 204
    assert_equal initial_views, final_views - 1
    end
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
    Channel::V2::ApiSolutions::ArticlesController.any_instance.unstub(:agent?)
  end

  def test_article_hit_with_invalid_params
    stub_channel_api do
      article_new = get_article_without_draft
      initial_views = @account.solution_articles.find(article_new.id).hits
      put :hit, controller_params(version: 'channel', id: article_new.id, invalid_params: 'invalid', source_type: 'freshchat')
      final_views = @account.solution_articles.find(article_new.id).hits
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'invalid_params', message: "Unexpected/invalid field in request", code: 'invalid_field' }] }
 
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_invalid_language_params_for_article_hit
    stub_channel_api do
      article_new = get_article_without_draft
      put :hit, controller_params(version: 'channel', id: article_new.id, language: 'en-us', source_type: 'freshchat')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'en-us', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end
  end

  def test_article_hit_with_article_in_draft_state
    stub_channel_api do
      article_new = get_article
      article_new.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article_new.save!
      put :hit, controller_params(version: 'channel', id: article_new.id, source_type: 'freshchat')
      assert_response 405
    end
  end

  def test_article_hit_with_invalid_user_id
    stub_channel_api do
      article_new = get_article
      article_new.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article_new.save!
      put :hit, controller_params(version: 'channel', user_id: -1, id: article_new.id, source_type: 'freshchat')
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'user_id', message: "must be greater than 0", code: 'invalid_value' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_article_hit_without_source_type_params
    stub_channel_api do
      article_new = get_article
      article_new.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article_new.save!
      put :hit, controller_params(version: 'channel', id: article_new.id)
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'source_type', message: "Mandatory attribute missing", code: 'missing_field' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_article_hit_with_invalid_source_id_params
    stub_channel_api do
      article_new = get_article
      article_new.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article_new.save!
      put :hit, controller_params(version: 'channel', id: article_new.id, source_type: 'freshchat', source_id: -1)
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'source_id', message: "must be greater than 0", code: 'invalid_value' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_article_hit_with_valid_user_id_source_id_and_source_type
    stub_channel_api do
      Channel::V2::ApiSolutions::ArticlesController.any_instance.stubs(:agent?).returns(false)
      article_new = get_article_without_draft
      user = add_new_user(@account)
      initial_views = @account.solution_articles.find(article_new.id).hits
      put :hit, controller_params(version: 'channel', id: article_new.id, user_id: user.id, source_type: 'freshchat', source_id: 1)
      final_views = @account.solution_articles.find(article_new.id).hits
      assert_response 204
      assert_equal initial_views, final_views - 1
    end
    Channel::V2::ApiSolutions::ArticlesController.any_instance.unstub(:agent?)
  end

  def test_channel_hit_payload
    stub_channel_api do
      Channel::V2::ApiSolutions::ArticlesController.any_instance.stubs(:agent?).returns(false)
      article_new = get_article_without_draft
      user = add_new_user(@account)
      CentralPublishWorker::SolutionArticleWorker.jobs.clear
      put :hit, controller_params(version: 'channel', id: article_new.id, user_id: user.id, source_type: 'freshchat', source_id: 1)
      job = CentralPublishWorker::SolutionArticleWorker.jobs.first
      assert_response 204
      assert_equal 1, CentralPublishWorker::SolutionArticleWorker.jobs.size
      assert_equal user.id, job["args"][1]['current_user_id']
      assert_equal 3, job['args'][1]['event_info']['source_type']
      assert_equal 1, job['args'][1]['event_info']['source_id'].to_i
    end
    Channel::V2::ApiSolutions::ArticlesController.any_instance.unstub(:agent?)
  end
  
  def test_search
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article_title = Faker::Lorem.characters(10)
    article = create_article(article_params(title: article_title)).primary_article
    stub_private_search_response([article]) do
      get :search, controller_params(term: article_title)
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_platforms
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, platforms: 'ios')
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_tags
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    tag = Faker::Lorem.characters(7)
    create_tag_use(@account, taggable_type: 'Solution::Article', taggable_id: article.id, name: tag, allow_skip: true)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, tags: tag)
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_language
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article_title = Faker::Lorem.characters(10)
    article = create_article(article_params(title: article_title)).primary_article
    stub_private_search_response([article]) do
      get :search, controller_params(term: article_title, language: article.language_code)
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_prefer_published
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article_title = Faker::Lorem.characters(10)
    article = create_article(article_params(title: article_title, status: 2)).primary_article
    create_draft(article: article)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article_title, prefer_published: true, status: 2)
    end
    match_json([channel_api_solution_article_pattern(article, true, true)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_status
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article_title = Faker::Lorem.characters(10)
    article = create_article(article_params(title: article_title, status: 2)).primary_article
    create_draft(article: article)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article_title, status: 2)
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_with_language_fallback_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article_title = Faker::Lorem.characters(10)
    article = create_article(article_params(title: article_title, status: 2)).primary_article
    stub_private_search_response([article]) do
      get :search, controller_params(term: article_title, allow_language_fallback: 'true')
    end
    match_json([channel_api_solution_article_pattern(article)])
    assert_response 200
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_invalid_param
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, test: 'test')
    end
    assert_response 400
    match_json([bad_request_error_pattern('test', :invalid_field)])
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_without_term
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(platforms: 'ios')
    end
    match_json([bad_request_error_pattern('term', 'Mandatory attribute missing', code: :missing_field)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_invalid_platform
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, platforms: 'test')
    end
    match_json([bad_request_error_pattern('platforms', "It should be one of these values: 'web,ios,android'", code: :invalid_value)])
    assert_response 400
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_invalid_language
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, language: 'test')
    end
    assert_response 404
    match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_without_multilingual_feature
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    Account.any_instance.stubs(:multilingual?).returns(false)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, language: 'ar')
    end
    assert_response 404
    match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.any_instance.unstub(:multilingual?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_search_without_omni_bundle
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(KBSERVICE)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, platforms: 'ios')
    end
    assert_response 403
    match_json(validation_error_pattern(bad_request_error_pattern('platforms', :require_feature, feature: :omni_bundle_2020, code: :access_denied)))
  ensure
    CustomRequestStore.unstub(:read)
  end

  def test_search_without_access
    @enrich_response = false
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    Account.any_instance.stubs(:omni_bundle_account?).returns(true)
    Account.current.launch(:kbase_omni_bundle)
    article = get_article_with_platform_mapping(ios: true, web: true, android: false)
    stub_private_search_response([article]) do
      get :search, controller_params(term: article.title, platforms: 'ios')
    end
    assert_response 401
    match_json(request_error_pattern(:invalid_credentials))
  ensure
    Account.any_instance.unstub(:omni_bundle_account?)
    Account.current.rollback :kbase_omni_bundle
    CustomRequestStore.unstub(:read)
  end

  def test_article_thumbs_up_invalid_user
    stub_channel_api do
      language = Language.find_by_code('ru-RU')
      article = get_article_without_draft(language)
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, language: 'ru-RU', user_id: 'invalid', source_type: 'freshchat')
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'user_id', message: "is not a number", code: 'invalid_value' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_article_thumbs_up_with_invalid_language
    stub_channel_api do
      language = Language.find_by_code('ru-RU')
      article = get_article_without_draft(language)
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, language: 'invalid', source_type: 'freshchat')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'invalid', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end
  end

  def test_article_thumbs_up
    stub_channel_api do
      article = get_article_without_draft
      @controller.stubs(:current_user).returns(nil)
      old_thumbs_up = article.thumbs_up
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_up, old_thumbs_up + 1
    end
  ensure
    @controller.unstub(:current_user)
  end

  def test_article_thumbs_up_with_user
    stub_channel_api do
      article = get_article_without_draft
      article.votes.map(&:destroy)
      old_thumbs_up = article.thumbs_up
      user = add_new_user(@account)
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_up, old_thumbs_up + 1
      assert_equal article.votes.last.user_id, user.id
      assert_equal article.votes.last.vote, 1
    end
  end
  
  def test_article_thumbs_down_invalid_user
    stub_channel_api do
      language = Language.find_by_code('ru-RU')
      article = get_article_without_draft(language)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, language: 'ru-RU', user_id: 'invalid', source_type: 'freshchat')
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'user_id', message: "is not a number", code: 'invalid_value' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end
  
  def test_article_thumbs_down_with_invalid_language
    stub_channel_api do
      language = Language.find_by_code('ru-RU')
      article = get_article_without_draft(language)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, language: 'invalid', source_type: 'freshchat')
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: 'invalid', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end
  end
  
  def test_article_thumbs_down
    stub_channel_api do
      article = get_article_without_draft
      @controller.stubs(:current_user).returns(nil)
      old_thumbs_down = article.thumbs_down
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_down, old_thumbs_down + 1
    end
  ensure
    @controller.unstub(:current_user)
  end
  
  def test_article_thumbs_down_with_user
    stub_channel_api do
      article = get_article_without_draft
      old_thumbs_down = article.thumbs_down
      user = add_new_user(@account)
      article.votes.map(&:destroy)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_down, old_thumbs_down + 1
      assert_equal article.votes.last.user_id, user.id
      assert_equal article.votes.last.vote, 0
    end
  end

  def test_article_thumbs_down_with_source_type_and_id
    stub_channel_api do
      article = get_article_without_draft
      old_thumbs_down = article.thumbs_down
      user = add_new_user(@account)
      article.votes.map(&:destroy)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat', source_id: 1)
      assert_response 204
      assert_equal article.reload.thumbs_down, old_thumbs_down + 1
      assert_equal article.votes.last.user_id, user.id
      assert_equal article.votes.last.vote, 0
    end
  end

  def test_article_thumbs_down_with_optional_source_id
    stub_channel_api do
      article = get_article_without_draft
      old_thumbs_down = article.thumbs_down
      user = add_new_user(@account)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_down, old_thumbs_down + 1
      assert_equal article.votes.last.user_id, user.id
      assert_equal article.votes.last.vote, 0
    end
  end

  def test_article_thumbs_down_without_source_type
    stub_channel_api do
      article = get_article_without_draft
      user = add_new_user(@account)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_id: 1)
      assert_response 400
      expected = { description: 'Validation failed', errors: [{ field: 'source_type', message: "Mandatory attribute missing", code: 'missing_field' }] }
      assert_equal(expected, JSON.parse(response.body, symbolize_names: true))
    end
  end

  def test_article_thumbs_down_with_draft_article
    stub_channel_api do
      article = get_article
      article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article.save!
      user = add_new_user(@account)
      put :thumbs_down, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_id: 1, source_type: 'freshchat')
      assert_response 405
    end
  end

  def test_article_thumbs_up_with_draft_article
    stub_channel_api do
      article = get_article
      article.status = Solution::Article::STATUS_KEYS_BY_TOKEN[:draft]
      article.save!
      user = add_new_user(@account)
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_id: 1, source_type: 'freshchat')
      assert_response 405
    end
  end

  def test_article_thumbs_up_without_agent_metrics
    stub_channel_api do
      puts ">>>>>>>>>START<<<<<<<<<<"
      Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(false)
      article = get_article_without_draft
      old_thumbs_up = article.thumbs_up
      user = @account.agents.first.user
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat')
      assert_response 204
      puts ">>>>>>>>>END<<<<<<<<<<"
      assert_equal article.reload.thumbs_up, old_thumbs_up
    end
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
  end

  def test_article_thumbs_up_with_agent_metrics
    stub_channel_api do
      Account.any_instance.stubs(:solutions_agent_metrics_enabled?).returns(true)
      article = get_article_without_draft
      old_thumbs_up = article.thumbs_up
      user = @account.agents.first.user
      put :thumbs_up, controller_params(version: 'channel', id: article.parent_id, user_id: user.id, source_type: 'freshchat')
      assert_response 204
      assert_equal article.reload.thumbs_up, old_thumbs_up + 1
    end
  ensure
    Account.any_instance.unstub(:solutions_agent_metrics_enabled?)
  end

  private

  def stub_channel_api
    CustomRequestStore.stubs(:read).with(:channel_api_request).returns(true)
    CustomRequestStore.stubs(:read).with(:private_api_request).returns(false)
    set_jwt_auth_header(FRESHCONNECT_SRC)
    yield
  ensure
    CustomRequestStore.unstub(:read)
  end

  def get_articles_by_portal_id(portal_id, language = Account.current.language_object)
    @account.solution_articles.joins(solution_folder_meta: [solution_category_meta: :portal_solution_categories]).where('portal_solution_categories.portal_id = ? AND language_id = ?', portal_id, language)
  end

  def create_article_in_portal
    category = create_category(portal_id: Account.current.main_portal.id, lang_codes: [@account.language_object.code])
    folder = create_folder(visibility: 1, category_id: category.id, lang_codes: [@account.language_object.code])
    article_meta = create_article(folder_id: folder.id, lang_codes: [@account.language_object.code])
    article_meta
  end
end
