module ApiSolutions
  class CategoriesController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    decorate_views

    def create
      render_201_with_location(item_id: @item.parent_id) if manage_category
    end

    def update
      manage_category
    end

    def destroy
      @meta.destroy
      head 204
    end

    private

      def scoper
        current_account.solution_categories
      end

      def meta_scoper
        current_account.solution_category_meta.where(is_default: false)
      end

      def manage_category
        category_delegator = CategoryDelegator.new(@category_params[:portal_ids])
        if category_delegator.valid?
          @meta = Solution::Builder.category(solution_category_meta: @category_params, language_id: @lang_id)
          @item = @meta.send(language_scoper)
          if @item.errors.any?
            render_custom_errors
          else
            return true
          end
        else
          render_custom_errors(category_delegator, true)
        end
        false
      end

      def before_load_object
        validate_language
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
        params[cname].permit(*(SolutionConstants::CATEGORY_FIELDS))
        category = ApiSolutions::CategoryValidation.new(params[cname], @item)
        render_errors category.errors, category.error_options unless category.valid?
      end

      def sanitize_params
        prepare_array_fields [:visible_in]
        language_params = params[cname].slice(:name, :description)
        params[cname][language_scoper] = language_params unless language_params.empty?
        params[cname][:id] = params[:id]
        ParamsHelper.assign_and_clean_params({ :visible_in => :portal_ids }, params[cname])
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

      def validate_filter_params
        validate_language
      end

      def load_objects(items = scoper)
        super(items.where(language_id: @lang_id).preload(:solution_category_meta))
      end

      def load_meta(id)
        meta = meta_scoper.find_by_id(id)
        log_and_render_404 unless meta
        meta
      end
  end
end
