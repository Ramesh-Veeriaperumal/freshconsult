require_relative '../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module ApiSolutions
  class ArticlesControllerTest < ActionController::TestCase
    include SolutionsTestHelper
    include AttachmentsTestHelper
    include PrivilegesHelper
    include SolutionsHelper
    include SolutionBuilderHelper
    include SolutionsArticlesTestHelper
    include SolutionsArticlesCommonTests

    def setup
      super
      initial_setup
      @account.reload
    end

    @@initial_setup_run = false

    def initial_setup
      @portal_id = Account.current.main_portal.id
      return if @@initial_setup_run
      MixpanelWrapper.stubs(:send_to_mixpanel).returns(true)
      Account.stubs(:current).returns(@account)
      $redis_others.perform_redis_op('set', 'ARTICLE_SPAM_REGEX', '(gmail|kindle|face.?book|apple|microsoft|google|aol|hotmail|aim|mozilla|quickbooks|norton).*(support|phone|number)')
      $redis_others.perform_redis_op('set', 'PHONE_NUMBER_SPAM_REGEX', '(1|I)..?8(1|I)8..?85(0|O)..?78(0|O)6|(1|I)..?877..?345..?3847|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?8(0|O)(0|O)..?79(0|O)..?9(1|I)86|(1|I)..?8(0|O)(0|O)..?436..?(0|O)259|(1|I)..?8(0|O)(0|O)..?969..?(1|I)649|(1|I)..?844..?922..?7448|(1|I)..?8(0|O)(0|O)..?75(0|O)..?6584|(1|I)..?8(0|O)(0|O)..?6(0|O)4..?(1|I)88(0|O)|(1|I)..?877..?242..?364(1|I)|(1|I)..?844..?782..?8(0|O)96|(1|I)..?844..?895..?(0|O)4(1|I)(0|O)|(1|I)..?844..?2(0|O)4..?9294|(1|I)..?8(0|O)(0|O)..?2(1|I)3..?2(1|I)7(1|I)|(1|I)..?855..?58(0|O)..?(1|I)8(0|O)8|(1|I)..?877..?424..?6647|(1|I)..?877..?37(0|O)..?3(1|I)89|(1|I)..?844..?83(0|O)..?8555|(1|I)..?8(0|O)(0|O)..?6(1|I)(1|I)..?5(0|O)(0|O)7|(1|I)..?8(0|O)(0|O)..?584..?46(1|I)(1|I)|(1|I)..?844..?389..?5696|(1|I)..?844..?483..?(0|O)332|(1|I)..?844..?78(0|O)..?675(1|I)|(1|I)..?8(0|O)(0|O)..?596..?(1|I)(0|O)65|(1|I)..?888..?573..?5222|(1|I)..?855..?4(0|O)9..?(1|I)555|(1|I)..?844..?436..?(1|I)893|(1|I)..?8(0|O)(0|O)..?89(1|I)..?4(0|O)(0|O)8|(1|I)..?855..?662..?4436')
      $redis_others.perform_redis_op('set', 'CONTENT_SPAM_CHAR_REGEX', 'ℴ|ℕ|ℓ|ℳ|ℱ|ℋ|ℝ|ⅈ|ℯ|ℂ|○|ℬ|ℂ|ℙ|ℹ|ℒ|ⅉ|ℐ')
      additional = @account.account_additional_settings
      additional.supported_languages = ['es', 'ru-RU']
      additional.save
      @account.features.enable_multilingual.create
      subscription = @account.subscription
      subscription.state = 'active'
      subscription.save
      @account.reload
      setup_articles
      @@initial_setup_run = true
      MixpanelWrapper.unstub(:send_to_mixpanel)
      Account.unstub(:current)
    end

    def setup_articles
      # dont destroy articles from setup_articles in any of our test cases
      @@category_meta = Solution::CategoryMeta.last

      @folder_meta = Solution::FolderMeta.new
      @folder_meta.visibility = 1
      @folder_meta.solution_category_meta = @@category_meta
      @folder_meta.account = @account
      @folder_meta.save
      @@folder_meta = @folder_meta

      @folder = Solution::Folder.new
      @folder.name = "test folder #{Time.zone.now}"
      @folder.description = 'test description'
      @folder.account = @account
      @folder.parent_id = @folder_meta.id
      @folder.language_id = Language.find_by_code('en').id
      @folder.save
      @@folder = @folder

      @articlemeta = Solution::ArticleMeta.new
      @articlemeta.art_type = 1
      @articlemeta.solution_folder_meta_id = @folder_meta.id
      @articlemeta.solution_category_meta = @folder_meta.solution_category_meta
      @articlemeta.account_id = @account.id
      @articlemeta.published = false
      @articlemeta.save
      @@articlemeta = @articlemeta

      @article = Solution::Article.new
      @article.title = "Sample #{Time.zone.now}"
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
      temp_article.title = "Sample article without draft #{Time.zone.now}"
      temp_article.description = '<b>Test</b>'
      temp_article.status = 2
      temp_article.language_id = @account.language_object.id
      temp_article.parent_id = temp_article_meta.id
      temp_article.account_id = @account.id
      temp_article.user_id = @account.agents.first.id
      temp_article.save

      create_draft(article: @article)

      @category = Solution::Category.new
      @category.name = "es category #{Time.zone.now}"
      @category.description = 'es cat description'
      @category.language_id = Language.find_by_code('es').id
      @category.parent_id = @@category_meta.id
      @category.account = @account
      @category.save

      @folder = Solution::Folder.new
      @folder.name = "es folder #{Time.zone.now}"
      @folder.description = "es folder description #{Time.zone.now}"
      @folder.account = @account
      @folder.parent_id = @folder_meta.id
      @folder.language_id = Language.find_by_code('es').id
      @folder.save

      @article_with_lang = Solution::Article.new
      @article_with_lang.title = 'es article'
      @article_with_lang.description = '<b>aaa</b>'
      @article_with_lang.status = 1
      @article_with_lang.language_id = Language.find_by_code('es').id
      @article_with_lang.parent_id = @articlemeta.id
      @article_with_lang.account_id = @account.id
      @article_with_lang.user_id = @account.agents.first.id
      @article_with_lang.save
    end

    def wrap_cname(params)
      { article: params }
    end

    def test_folder_index_without_multilingual_feature
      Account.any_instance.stubs(:multilingual?).returns(false)
      sample_folder = get_folder_meta
      non_supported_language = get_valid_not_supported_language
      get :folder_articles, controller_params(version: version, id: sample_folder.id, language: non_supported_language)
      assert_response 404
      match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
    ensure
      Account.any_instance.unstub(:multilingual?)
    end

    def test_folder_index_with_invalid_language_param
      sample_folder = get_folder_meta
      non_supported_language = get_valid_not_supported_language
      get :folder_articles, controller_params(version: version, id: sample_folder.id, language: non_supported_language)
      assert_response 404
      match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
    end

    private

      def version
        'v2'
      end

      def article_pattern(article, expected_output = {})
        solution_article_pattern(expected_output, article)
      end

      def article_draft_pattern(article, draft)
        solution_article_draft_pattern(article, draft)
      end

      def article_pattern_index(article)
        solution_article_pattern_index(article)
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
  end
end
