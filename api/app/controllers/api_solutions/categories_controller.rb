module ApiSolutions
  class CategoriesController < ApiApplicationController
    include SolutionConcern
    include HelperConcern
    include Solution::LanguageControllerMethods
    decorate_views

    before_filter :sanitize_boolean_params, only: [:index]

    def index
      super if validate_language
    end

    def create
      if create_or_update_category
        render_201_with_location(item_id: @item.parent_id)
      else
        render_solution_item_errors
      end
    end

    def update
      render_solution_item_errors unless create_or_update_category
    end

    def destroy
      @meta.destroy
      head 204
    end

    private

      def scoper
        solutions_scoper.solution_categories
      end

      def meta_scoper
        current_account.solution_category_meta.where(is_default: false)
      end

      def create_or_update_category
        @meta = Solution::Builder.category(solution_category_meta: @category_params, language_id: @lang_id)
        @item = @meta.safe_send(language_scoper)
        !(@item.errors.any? || @item.parent.errors.any?)
      end

      def before_load_object
        sanitize_boolean_params
        validate_language
      end

      def sanitize_boolean_params
        params[:allow_language_fallback] = params[:allow_language_fallback].to_bool if boolean_param?(:allow_language_fallback)
      end

      def load_object(items = scoper)
        @meta = load_meta(params[:id])
        @item = items.where(parent_id: params[:id], language_id: @lang_id).first
        log_and_render_404 unless @item
      end

      def validate_params
        if create?
          return false unless validate_language
        end
        return unless validate_body_params(@item)
        return unless validate_delegator(nil, cname_params)
      end

      def sanitize_params
        prepare_array_fields [:visible_in_portals]
        language_params = params[cname].slice(:name, :description)
        params[cname][language_scoper] = language_params unless language_params.empty?
        params[cname][:id] = params[:id] if params.key?(:id)
        params[cname][:portal_solution_categories_attributes] = { portal_id:  params[cname].delete(:visible_in_portals) } if params[cname].key?(:visible_in_portals) && params[cname][:visible_in_portals].any?
        @category_params = params[cname].except!(:name, :description)
      end

      def build_object
        if params.key?(:id) && params.key?(:language)
          load_meta(params[:id])
          @item = scoper.where(parent_id: params[:id], language_id: @lang_id).first
          if @item.nil?
            @item = Solution::Category.new
          else
            render_base_error(:method_not_allowed, 405, methods: 'GET, PUT', fired_method: 'POST')
          end
        end
      end

      def constants_class
        'ApiSolutions::CategoryConstants'.freeze
      end

      def validate_filter_params
        @validation_klass = 'ApiSolutions::CategoryFilterValidation'.freeze
        return unless validate_query_params
        return unless validate_delegator(nil, portal_id: params[:portal_id])
      end

      def load_objects(items = scoper)
        @items = if params[:portal_id].present?
                   items.where(language_id: @lang_id).preload(solution_category_meta: :portal_solution_categories)
                 else
                   items.where(language_id: @lang_id).joins(:solution_category_meta).where('solution_category_meta.is_default = false').preload(solution_category_meta: :portal_solution_categories)
                 end
        super(@items) unless private_api?
      end

      def load_meta(id)
        meta = meta_scoper.find_by_id(id)
        log_and_render_404 unless meta
        meta
      end
  end
end
