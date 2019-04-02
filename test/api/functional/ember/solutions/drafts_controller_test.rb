require_relative '../../../test_helper'
['solutions_helper.rb', 'solution_builder_helper.rb'].each { |file| require Rails.root.join('spec', 'support', file) }

module Ember
  module Solutions
    class DraftsControllerTest < ActionController::TestCase
      include SolutionsTestHelper
      include SolutionsHelper
      include SolutionBuilderHelper

      def setup
        super
        before_all
      end

      @@before_all_run = false

      def before_all
        return if @@before_all_run

        subscription = @account.subscription
        subscription.state = 'active'
        subscription.save
        @account.reload
        setup_articles
        @@before_all_run = true
      end

      def setup_articles
        4.times do
          article_meta = create_article(article_params)
          draft = article_meta.primary_article.build_draft_from_article
          draft.save
        end
      end

      def test_index
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        drafts = get_my_drafts
        assert_equal response.api_meta[:count], drafts.size
        pattern = drafts.first(3).map { |draft| private_api_solution_article_pattern(draft.article, {}, true, nil, draft) }
        match_json(pattern)
      end

      def test_index_without_privilege
        User.any_instance.stubs(:privilege?).with(:view_solutions).returns(false)
        get :index, controller_params(version: 'private')
        assert_response 403
        match_json(request_error_pattern(:access_denied))
        User.any_instance.unstub(:privilege?)
      end

      def test_index_without_portal_id
        get :index, controller_params(version: 'private')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :datatype_mismatch, code: :missing_field, expected_data_type: String)])
      end

      def test_index_with_additional_field
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id, test: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern('test', :invalid_field)])
      end

      def test_index_with_invalid_portal_id
        get :index, controller_params(version: 'private', portal_id: 'Test')
        assert_response 400
        match_json([bad_request_error_pattern(:portal_id, :invalid_portal_id)])
      end

      private

        def get_my_drafts
          @account.solution_drafts.where(user_id: User.current.id).joins(:article, category_meta: :portal_solution_categories).where('portal_solution_categories.portal_id = ? AND solution_articles.language_id = ?', @account.main_portal.id, 6).order('modified_at desc')
        end

    end
  end
end