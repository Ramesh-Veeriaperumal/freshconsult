require_relative '../../../../test_helper'
require Rails.root.join('test', 'models', 'helpers', 'tag_use_test_helper.rb')
class Channel::V2::ApiSolutions::ArticlesControllerTest < ActionController::TestCase
  include JweTestHelper
  include SolutionsTestHelper
  include SolutionsArticlesTestHelper
  include CoreSolutionsTestHelper
  include SolutionsPlatformsTestHelper
  include TagUseTestHelper
  SUPPORT_BOT = 'frankbot'.freeze
  FRESHCONNECT_SRC = 'freshconnect'.freeze

  def setup
    super
    initial_setup
  end

  @@initial_setup_run = false

  def initial_setup
    return if @@initial_setup_run
    Account.stubs(:current).returns(@account)
    setup_multilingual(supported_languages = ['es', 'ru-RU'])
    subscription = @account.subscription
    subscription.state = 'active'
    subscription.save
    @account.reload
    setup_articles
    @@initial_setup_run = true
    Account.unstub(:current)
  end

  def setup_articles
    @category_meta = Solution::CategoryMeta.last

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

    @draft = Solution::Draft.new
    @draft.account = @account
    @draft.article = @article
    @draft.title = 'Sample'
    @draft.category_meta = @article.solution_folder_meta.solution_category_meta
    @draft.status = 1
    @draft.description = '<b>aaa</b>'
    @draft.save

    @draft_body = Solution::DraftBody.new
    @draft_body.draft = @draft
    @draft_body.description = '<b>aaa</b>'
    @draft_body.account = @account
    @draft_body.save

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
    @folder.language_id = Language.find_by_code('ru-RU').id
    @folder.save

    @articlemeta = Solution::ArticleMeta.new
    @articlemeta.art_type = 1
    @articlemeta.solution_folder_meta_id = @folder_meta.id
    @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
    @articlemeta.account_id = @account.id
    @articlemeta.published = false
    @articlemeta.save

    @article_with_lang = Solution::Article.new
    @article_with_lang.title = 'Sample'
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

    get :show, controller_params(id: sample_article.id, language: 'ru-RU')

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
    get :folder_articles, controller_params(version: 'channel', id: folder.id, language: 'ru-RU')
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
    get :folder_articles, controller_params(id: folder.id, language: @account.language_object.code, portal_id: @account.main_portal.id)
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
    get :folder_articles, controller_params(id: sample_folder.id, platforms: 'ios')
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
    get :folder_articles, controller_params(id: sample_folder.id, tags: tag)
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
    get :folder_articles, controller_params(id: sample_folder.id, tags: '')
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
    get :folder_articles, controller_params(id: sample_folder.id, platforms: '')
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
    get :folder_articles, controller_params(id: sample_folder.id, platforms: 'ios')
    assert_response 403
    match_json(validation_error_pattern(bad_request_error_pattern('platforms', :require_feature, feature: :omni_bundle_2020, code: :access_denied)))
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
