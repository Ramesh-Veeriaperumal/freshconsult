require_relative '../../../test_helper'
module Ember
  module Solutions
    class CategoriesControllerTest < ActionController::TestCase
      # We can remove it when we add category controller class in ember namespace
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

      def test_reorder_without_privilege
        User.any_instance.stubs(:privilege?).with(:manage_solutions).returns(false)
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params({ version: 'private', id: portal_solution_categories.first.solution_category_meta_id }, position: 1)
        assert_response 403
      ensure
        User.any_instance.unstub(:privilege?)
      end

      def test_reorder_without_position
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params(version: 'private', id: portal_solution_categories.first.solution_category_meta_id, portal_id: @account.main_portal.id)
        match_json(validation_error_pattern(:position, :missing_field))
      end

      def test_reorder_without_portal_id
        populate_categories(@account.main_portal)
        portal_solution_categories = @account.main_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        put :reorder, construct_params({ version: 'private', id: portal_solution_categories.first.solution_category_meta_id }, position: 1)
        assert_response 400
        match_json(validation_error_pattern(:portal_id, :invalid_value))
      end

      def test_reorder
        populate_categories(@account.main_portal)
        portal = @account.main_portal
        portal_solution_categories = @account.main_portal.portal_solution_categories.reorder('portal_solution_categories.position').joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
        old_id_order = portal_solution_categories.pluck(:solution_category_meta_id)
        put :reorder, construct_params({ version: 'private', portal_id: @account.main_portal.id, id: portal_solution_categories.first.solution_category_meta_id }, position: 7)
        assert_response 204
        new_id_order = portal_solution_categories.reload.pluck(:solution_category_meta_id)
        assert old_id_order.slice(1, 6) == new_id_order.slice(0, 6)
        assert old_id_order[0] == new_id_order[6]
        assert old_id_order.slice(7, old_id_order.size) == new_id_order.slice(7, new_id_order.size)
      end

      private

        def get_category
          @account.solution_category_meta.where(is_default: false).select(&:children).first
        end

        def populate_categories(portal)
          return if portal.portal_solution_categories.size > 10

          (1..10).each do |index|
            category_meta = Solution::CategoryMeta.new(account_id: @account.id, is_default: false)
            category_meta.save

            category = Solution::Category.new
            category.name = "#{Faker::Name.name} #{index}"
            category.description = 'es cat description'
            category.language_id = Language.find_by_code(@account.language).id
            category.parent_id = category_meta.id
            category.account = @account
            category.save
          end
        end
    end
  end
end
