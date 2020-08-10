require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }
require 'sidekiq/testing'
Sidekiq::Testing.fake!

module Ember
  module Solutions
    class HomeControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper
      include ArchiveTicketTestHelper
      include TicketHelper
      include SolutionsTemplatesTestHelper

      ARCHIVE_DAYS = 30

      def setup
        super
        before_all
        @account.make_current
        @account.features.enable_multilingual.create
        @account.enable_ticket_archiving(ARCHIVE_DAYS)
        Sidekiq::Worker.clear_all
        @account.features.send(:archive_tickets).create
        create_archive_ticket_with_assoc(created_at: 40.days.ago, updated_at: 40.days.ago, create_association: true)
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        additional = @account.account_additional_settings
        additional.supported_languages = ['es', 'ru-RU']
        additional.save
        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        @@before_all_run = true
      end

      def test_summary_with_incorrect_credentials
        @controller.stubs(:api_current_user).raises(ActiveSupport::MessageVerifier::InvalidSignature)
        get :summary, controller_params(version: 'private')
        assert_response 401
        assert_equal request_error_pattern(:credentials_required).to_json, response.body
        @controller.unstub(:api_current_user)
      end

      def test_summary_without_view_solutions_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :summary, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_summary_without_access
        user = add_new_user(@account, active: true)
        login_as(user)
        get :summary, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        @admin = get_admin
        login_as(@admin)
      end

      def test_summary_without_portal_id
        get :summary, controller_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern('portal_id', :missing_field)])
      end

      def test_summary_with_invalid_field
        get :summary, controller_params(version: 'private', portal_id: Account.current.main_portal.id, test: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_summary_with_invalid_portal_id
        get :summary, controller_params(version: 'private', portal_id: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
      end

      def test_summary
        portal_id = Account.current.main_portal.id
        language = Account.current.language_object
        create_article(article_params)
        get :summary, controller_params(version: 'private', portal_id: portal_id)
        assert_response 200
        match_json(summary_pattern(portal_id, language))
      end

      def test_summary_with_language_without_multilingual_feature
        Account.any_instance.stubs(:multilingual?).returns(false)
        portal_id = Account.current.main_portal.id
        get :summary, controller_params(version: 'private', portal_id: portal_id, language: @account.supported_languages.last)
        match_json(request_error_pattern(:require_feature, feature: 'MultilingualFeature'))
        assert_response 404
      ensure
        Account.any_instance.unstub(:multilingual?)
      end

      def test_summary_with_invalid_language
        portal_id = Account.current.main_portal.id
        get :summary, controller_params(version: 'private', portal_id: portal_id, language: 'test')
        assert_response 404
        match_json(request_error_pattern(:language_not_allowed, code: 'test', list: (@account.supported_languages + [@account.language]).sort.join(', ')))
      end

      def test_summary_with_primary_language
        portal_id = Account.current.main_portal.id
        language = Account.current.language_object
        create_article(article_params)
        get :summary, controller_params(version: 'private', portal_id: portal_id, language: @account.language)
        assert_response 200
        match_json(summary_pattern(portal_id, language))
      end

      def test_summary_with_supported_language
        portal_id = Account.current.main_portal.id
        languages = @account.supported_languages + ['primary']
        language = @account.supported_languages_objects.first
        article_meta = create_article(article_params(lang_codes: languages))
        get :summary, controller_params(version: 'private', portal_id: portal_id, language: language.code)
        assert_response 200
        match_json(summary_pattern(portal_id, language))
      end

      def test_quick_views_without_portal_id
        get :quick_views, controller_params(version: 'private')
        assert_response 200
        match_json(quick_views_pattern)
      end

      def test_quick_views_with_invalid_portal_id
        portal_id = Account.current.portals.last.id
        get :quick_views, controller_params(version: 'private', portal_id: portal_id + 1)
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
      end

      def test_quick_views_portal_with_no_categories
        portal = create_portal
        category_meta = portal.solution_category_meta.where(is_default: false)
        Portal.any_instance.stubs(:solution_category_meta).returns(category_meta)
        get :quick_views, controller_params(version: 'private', portal_id: portal.id)
        Portal.any_instance.unstub(:solution_category_meta)
        assert_response 200
      end

      def test_quick_views_with_user_not_having_view_solutions_privilege
        portal = Account.current.main_portal
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :quick_views, controller_params(version: 'private', portal_id: portal.id)
        assert_response 403
        match_json(request_error_pattern(:access_denied))
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_quick_views_with_valid_params
        solution_test_setup
        category = create_category
        @account.portal_solution_categories.where(solution_category_meta_id: category.id).last.destroy
        create_article(article_params)
        portal = Account.current.main_portal
        get :quick_views, controller_params(version: 'private', portal_id: portal.id)
        assert_response 200
        match_json(quick_views_pattern(portal.id))
      end

      def test_quick_views_with_archive_tickets
        # article tickets that are archived should not be present in feedback count
        stub_archive_assoc_for_show(@archive_association) do
          portal = Account.current.main_portal
          article_meta = create_article(article_params)
          archive_ticket = @account.archive_tickets.find_by_ticket_id(@archive_ticket.id)
          article_ticket = @archive_ticket.build_article_ticket(article_id: article_meta.primary_article.id)
          article_ticket.ticketable_type = 'Helpdesk::ArticleTicket'
          article_ticket.save!
          article_ticket.reload
          get :quick_views, controller_params(version: 'private', portal_id: portal.id)
          assert_response 200
          match_json(quick_views_pattern(portal.id))
        end
      end

      def test_quick_views_with_primary_language
        solution_test_setup
        create_article(article_params)
        portal = Account.current.main_portal
        get :quick_views, controller_params(version: 'private', portal_id: portal.id, language: @account.language)
        assert_response 200
        match_json(quick_views_pattern(portal.id, Language.find_by_code(@account.language).id))
      end

      def test_quick_views_with_secondary_language
        solution_test_setup
        language = Language.find_by_code(:es)
        create_article(article_params)
        portal = Account.current.main_portal
        get :quick_views, controller_params(version: 'private', portal_id: portal.id, language: language.code)
        assert_response 200
        match_json(quick_views_pattern(portal.id, language.id))
      end

      def test_quick_views_with_article_approval_workflow_enabled
        Account.any_instance.stubs(:article_approval_workflow_enabled?).returns(true)
        solution_test_setup
        create_article(article_params)
        portal = Account.current.main_portal
        get :quick_views, controller_params(version: 'private', portal_id: portal.id, language: @account.language)
        assert_response 200
        match_json(quick_views_pattern(portal.id, Language.find_by_code(@account.language).id))
      ensure
        Account.any_instance.unstub(:article_approval_workflow_enabled?)
      end

      def test_quick_views_with_templates_with_feature
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(true)
        solution_test_setup
        create_article(article_params)
        portal = Account.current.main_portal
        t1 = create_sample_template
        t2 = create_sample_template
        get :quick_views, controller_params(version: 'private', portal_id: portal.id, language: @account.language)
        assert_response 200
        match_json(quick_views_pattern(portal.id, Language.find_by_code(@account.language).id))
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
        t1.destroy
        t2.destroy
      end

      def test_quick_views_with_templates_without_feature
        Account.any_instance.stubs(:solutions_templates_enabled?).returns(false)
        solution_test_setup
        create_article(article_params)
        portal = Account.current.main_portal
        t1 = create_sample_template
        t2 = create_sample_template
        get :quick_views, controller_params(version: 'private', portal_id: portal.id, language: @account.language)
        assert_response 200
        match_json(quick_views_pattern(portal.id, Language.find_by_code(@account.language).id))
      ensure
        Account.any_instance.unstub(:solutions_templates_enabled?)
        t1.destroy
        t2.destroy
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
