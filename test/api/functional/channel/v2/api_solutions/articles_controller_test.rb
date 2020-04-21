require_relative '../../../../test_helper'
class Channel::V2::ApiSolutions::ArticlesControllerTest < ActionController::TestCase
  include JweTestHelper
  include SolutionsTestHelper
  include SolutionsArticlesTestHelper
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
    set_jwe_auth_header(SUPPORT_BOT)
    sample_article = get_article
    get :show, controller_params(id: sample_article.parent_id)
    assert_response 200
  end

  def test_show_published_article_without_draft_freshconnect_source
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
    set_jwe_auth_header(SUPPORT_BOT)
    sample_article = get_article
    create_draft(article: sample_article)
    get :show, controller_params(id: sample_article.parent_id, prefer_published: true)
    assert_response 200
    assert_not_equal '<b>draft body</b>', JSON.parse(response.body)[:description]
  end

  def get_article
    @account.solution_article_meta.map{ |x| x.children }.flatten.reject(&:blank?).first
  end
end
