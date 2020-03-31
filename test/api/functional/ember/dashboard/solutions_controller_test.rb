require_relative '../../../test_helper'

['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
require Rails.root.join('test', 'api', 'helpers', 'solutions_articles_test_helper.rb')


module Ember
  module Dashboard
    class SolutionsControllerTest < ActionController::TestCase

      include SolutionsArticlesTestHelper
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      @@before_all_run = false

      def setup
        super
        @account = Account.first
        Account.stubs(:current).returns(@account)
        setup_multilingual
        before_all
      end

      def teardown
        Account.unstub(:current)
      end

      def before_all
        return if @@before_all_run
        setup_redis_for_articles
        (1...10).each { create_article(article_params(lang_codes: all_account_languages)) }
        populate_performance_data
        @@before_all_run = true
      end

      def test_article_performance_without_portal_id
        get :article_performance, controller_params(version: 'private', language: @account.supported_languages.first)
        assert_response 400
      end

      def test_article_performance_without_language
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        match_json(article_performance_response(@account.main_portal.id, @account.language_object.id))
      end

      def test_article_performance_without_multilingual
        Account.any_instance.stubs(:multilingual?).returns(false)
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id, language: @account.supported_languages.first)
        assert_response 404
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_article_language_with_invalid_language
        non_supported_language = get_valid_not_supported_language
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id, language: non_supported_language)
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: non_supported_language, list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_article_performance_with_invalid_portal_id
        get :article_performance, controller_params(version: 'private', portal_id: 1_000_001, language: @account.supported_languages.first)
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', :invalid_portal_id)])
      end

      def test_article_performance_with_invalid_portal_id_datatype
        get :article_performance, controller_params(version: 'private', portal_id: 'qwerty', language: @account.supported_languages.first)
        assert_response 400
      end

      def test_article_performance_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id, language: @account.supported_languages.first)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_article_performance_with_invalid_field
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id, language: @account.supported_languages.first, dummy: 'asd')
        assert_response 400
      end

      def test_article_performance
        get :article_performance, controller_params(version: 'private', portal_id: @account.main_portal.id, language: @account.supported_languages.first)
        assert_response 200
        match_json(article_performance_response(@account.main_portal.id, Language.find_by_code(@account.supported_languages.first).id))
      end

      def test_translation_summary_without_portal_id
        get :translation_summary, controller_params(version: 'private')
        assert_response 400
      end

      def test_translation_summary_without_multilingual
        Account.current.features.enable_multilingual.destroy
        get :translation_summary, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 403
        match_json(request_error_pattern(:require_feature, feature: 'Enable Multilingual'))
      ensure
        setup_multilingual
      end

      def test_translation_summary_with_invalid_portal_id
        get :translation_summary, controller_params(version: 'private', portal_id: 1_000_001)
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', :invalid_portal_id)])
      end

      def test_translation_summary_with_invalid_portal_id_datatype
        get :translation_summary, controller_params(version: 'private', portal_id: 'qwerty')
        assert_response 400
      end

      def test_translation_summary_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :translation_summary, controller_params(version: 'private', portal_id: @account.main_portal.id, language: @account.supported_languages.first)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_translation_summary_with_invalid_field
        get :translation_summary, controller_params(version: 'private', portal_id: @account.main_portal.id, dummy: 'asd')
        assert_response 400
      end

      def test_translation_summary
        get :translation_summary, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        match_json(translation_summary_response(@account.main_portal.id))
      end

      private

        def article_params(options = {})
          lang_hash = { lang_codes: options[:lang_codes] }
          category = create_category({ portal_id: Account.current.main_portal.id }.merge(lang_hash))
          {
            title: options[:title] || "#{Faker::Name.name} #{rand(1_000_000)}",
            description: "#{Faker::Name.name} #{rand(1_000_000)}",
            folder_id: create_folder({ visibility: Solution::Constants::VISIBILITY_KEYS_BY_TOKEN[:anyone], category_id: category.id }.merge(lang_hash)).id,
            status: options[:status] || Solution::Article::STATUS_KEYS_BY_TOKEN[:published]
          }.merge(lang_hash)
        end

        def article_performance_response(portal_id, language_id)
          hits = 0
          thumbs_up = 0
          thumbs_down = 0
          Solution::Article.portal_articles(portal_id, [language_id]).find_each do |article|
            hits += article.hits
            thumbs_up += article.thumbs_up
            thumbs_down += article.thumbs_down
          end
          {
            hits: hits,
            thumbs_down: thumbs_down,
            thumbs_up: thumbs_up
          }
        end

        def translation_summary_response(portal_id)
          summary = {}
          Account.current.all_language_objects.each do |language|
            summary[language.code] = Solution::Article.portal_articles(portal_id, language.id).count
          end
          summary
        end

        def populate_performance_data
          assert Solution::Article.count != 0
          Solution::Article.all.each do |article|
            (0...rand(150)).each { article.hit! }
            (0...rand(150)).each { article.thumbs_down! }
            (0...rand(150)).each { article.thumbs_up! }
          end
        end
    end
  end
end
