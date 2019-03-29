require_relative '../../../test_helper'
module Ember
  module Solutions
    class CategoriesControllerTest < ActionController::TestCase
      # We can remove it when we add category controller class in ember namespace
      tests ApiSolutions::CategoriesController
      include SolutionsTestHelper

      def setup
        super
        @private_api = true
      end

      def wrap_cname(params)
        { category: params }
      end

      def test_index
        get :index, controller_params(version: 'private')
        assert_response 200
        categories = @account.reload.solution_categories.joins(:solution_category_meta).where('solution_categories.language_id = ?', @account.language_object.id).select { |x| x unless x.parent.is_default }
        pattern = categories.map { |category| solution_category_pattern(category) }
        match_json(pattern)
      end

      def test_index_with_portal_id
        get :index, controller_params(version: 'private', portal_id: @account.main_portal.id)
        assert_response 200
        categories = @account.reload.solution_categories.joins(:solution_category_meta, solution_category_meta: :portal_solution_categories).where('solution_categories.language_id = ? AND portal_solution_categories.portal_id = ?', @account.language_object.id, @account.main_portal.id).order('portal_solution_categories.position').select { |x| x unless x.parent.is_default }
        pattern = categories.map { |category| solution_category_pattern(category) }
        match_json(pattern)
      end

      private

        def get_category
          @account.solution_category_meta.where(is_default: false).select(&:children).first
        end
    end
  end
end
