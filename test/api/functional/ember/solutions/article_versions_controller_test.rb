require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class ArticleVersionsControllerTest < ActionController::TestCase
      include SolutionsArticleVersionsTestHelper
      include SolutionsArticlesTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        setup_multilingual
        before_all
        @account.add_feature(:article_versioning)
        create_article(article_params(lang_codes: all_account_languages))
      end

      def teardown
        Account.unstub(:current)
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run
        setup_redis_for_articles
        setup_multilingual
        @account.reload
        @@before_all_run = true
      end

      def test_index_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_feature
        disable_article_versioning do
          get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Article Versioning'))
        end
      end

      def test_index_with_invalid_article_id
        get :index, controller_params(version: 'private', article_id: 99_999_999)
        assert_response 404
      end

      def test_index_with_invalid_article_id_with_valid_language
        get :index, controller_params(version: 'private', language: 'en', article_id: 99_999_999)
        assert_response 404
      end

      def test_index_with_invalid_language
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id, language: 'dummy')
        assert_response 404
      end

      def test_index_with_non_supported_language
        non_supported_lang = get_valid_not_supported_language
        get :index, controller_params(version: 'private', article_id: get_article_with_versions.parent.id, language: non_supported_lang)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_lang, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_index_with_valid_language
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id, language: supported_lang.code)
        assert_response 200
        match_json(article_verion_index_pattern(article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.limit(30)))
      end

      def test_index_without_language
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id)
        assert_response 200
        match_json(article_verion_index_pattern(article_meta.safe_send("primary_article").solution_article_versions.latest.limit(30)))
      end

      def test_index_without_multilingual
        supported_lang = @account.all_language_objects.first
        Account.any_instance.stubs(:multilingual?).returns(false)
        article_meta = get_article_with_versions.parent
        get :index, controller_params(version: 'private', article_id: article_meta.id, language: supported_lang.code)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_show_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_show_without_feature
        disable_article_versioning do
          article = get_article_with_versions
          get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id)
          assert_response 403
          match_json(request_error_pattern(:require_feature, feature: 'Article Versioning'))
        end
      end

      def test_show_with_invalid_article_id
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: 99_999_999, id: article.solution_article_versions.last.id)
        assert_response 404
      end

      def test_show_with_invalid_version_id
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: 999_999_999)
        assert_response 404
      end

      def test_show_with_invalid_language
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: 'dummy')
        assert_response 404
      end

      def test_show_with_non_supported_language
        non_supported_lang = get_valid_not_supported_language
        article = get_article_with_versions
        get :show, controller_params(version: 'private', article_id: article.parent.id, id: article.solution_article_versions.last.id, language: non_supported_lang)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_lang, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_show_with_valid_language
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3Object.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.first
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
        assert_response 200
        match_json(article_verion_pattern(article_version))
      ensure
        AwsWrapper::S3Object.unstub(:read)
      end

      def test_show_without_language
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3Object.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.safe_send('primary_article').solution_article_versions.latest.first
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no)
        assert_response 200
        match_json(article_verion_pattern(article_version))
      ensure
        AwsWrapper::S3Object.unstub(:read)
      end

      def test_show_without_multilingual
        supported_lang = @account.all_language_objects.first
        article_meta = get_article_with_versions.parent
        AwsWrapper::S3Object.stubs(:read).returns('{"title": "title", "description":"description"}')
        article_version = article_meta.safe_send("#{supported_lang.to_key}_article").solution_article_versions.latest.first
        Account.any_instance.stubs(:multilingual?).returns(false)
        get :show, controller_params(version: 'private', article_id: article_meta.id, id: article_version.version_no, language: supported_lang.code)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      private

        def article_params(options = {})
          lang_hash = { lang_codes: options[:lang_codes] }
          category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
          {
            title: options[:title] || 'Test',
            description: 'Test',
            folder_id: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id,
            status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
          }.merge(lang_hash)
        end
    end
  end
end
