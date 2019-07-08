module Ember
  module Solutions
    class CategoriesController < ApiSolutions::CategoriesController
      include SolutionReorderConcern
      include SolutionConcern

      private

        def reorder_scoper
          solution_portal.portal_solution_categories.joins(:solution_category_meta).where('solution_category_meta.is_default' => false)
                         .reorder('portal_solution_categories.position')
                         .includes(:portal)
                         .readonly(false)
        end

        def validate_reorder_delegator
          @delegator_klass = 'ApiSolutions::ReorderDelegator'
          return unless validate_delegator(nil, portal_id: params[:portal_id])
        end

        def load_reorder_item
          @reorder_item ||= reorder_scoper.find_by_solution_category_meta_id(params[:id])
          log_and_render_404 unless @reorder_item
          @reorder_item
        end

        def render_201_with_location(template_name: "api_solutions/categories/#{action_name}", location_url: 'api_solutions_categories_url', item_id: @item.id)
          render template_name, location: safe_send(location_url, item_id), status: 201
        end

        # Since wrap params arguments are dynamic & needed for checking if the resource allows multipart, placing this at last.
        wrap_parameters(*wrap_params)
    end
  end
end
