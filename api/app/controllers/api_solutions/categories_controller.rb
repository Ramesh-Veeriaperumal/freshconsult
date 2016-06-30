module ApiSolutions
  class CategoriesController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    decorate_views

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
        current_account.solution_categories
      end

      def meta_scoper
        current_account.solution_category_meta.where(is_default: false)
      end

      def create_or_update_category
        @meta = Solution::Builder.category(solution_category_meta: @category_params, language_id: @lang_id)
        @item = @meta.send(language_scoper)
        !(@item.errors.any? || @item.parent.errors.any?)
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
        params[cname][:id] = params[:id] if params.key?(:id)
        params[cname][:portal_solution_categories_attributes] = { portal_id:  params[cname].delete(:visible_in) } if params[cname].key?(:visible_in)
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

      def set_custom_errors(item = @item)
        unless item.respond_to?(:parent)
          bad_portal_ids = item.portal_solution_categories.select { |x| x.errors.present? }.map(&:portal_id)
          item.errors[:visible_in] << :invalid_list if bad_portal_ids.present?
          @error_options = { remove: :"category.portal_solution_categories", visible_in: { list: "#{bad_portal_ids.join(', ')}" } }
        end
        @error_options
      end
  end
end
