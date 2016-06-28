module ApiSolutions
  class FoldersController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    decorate_views(decorate_objects: [:category_folders])

    def create
      render_201_with_location(item_id: @item.parent_id) if manage_folder
    end

    def update
      manage_folder
    end

    def destroy
      @meta.destroy
      head 204
    end

    def category_folders
      if validate_language
        @item = current_account.solution_category_meta.where(is_default: false).find_by_id(params[:id])
        if @item
          @items = paginate_items(@item.solution_folders.where(language_id: @lang_id))
          render '/api_solutions/folders/index'
        else
          log_and_render_404
        end
      else
        return false
      end
    end

    private

      def scoper
        current_account.solution_folders
      end

      def meta_scoper
        current_account.solution_folder_meta.where(is_default: false)
      end

      def manage_folder
        folder_delegator = FolderDelegator.new(@folder_params)
        if folder_delegator.valid?
          @meta = Solution::Builder.folder(solution_folder_meta: @folder_params, language_id: @lang_id)
          @item = @meta.send(language_scoper)
          if @item.errors.any?
            render_custom_errors
          else
            return true
          end
        else
          render_custom_errors(folder_delegator, true)
        end
        false
      end

      def category_exists?
        @item = current_account.solution_category_meta.where(is_default: false).find_by_id(params[:id])
        log_and_render_404 unless @item
      end

      # Load category if create endpoint is triggered with primitive language
      def load_category
        category_exists? if @lang_id == current_account.language_object.id
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
          load_category
        end
        params[cname].permit(*(SolutionConstants::FOLDER_FIELDS))
        folder = ApiSolutions::FolderValidation.new(params[cname], @item, @lang_id)
        render_errors folder.errors, folder.error_options unless folder.valid?(action_name.to_sym)
      end

      def sanitize_params
        prepare_array_fields [:company_ids]
        language_params = params[cname].slice(:name, :description)
        params[cname][language_scoper] = language_params unless language_params.empty?
        params[cname][category] = params[:id]
        ParamsHelper.assign_and_clean_params({ company_ids: :customer_folders_attributes }, params[cname])
        @folder_params = params[cname].except!(:name, :description)
      end

      def category
        create? && params[:language].nil? ? :solution_category_meta_id : :id
      end

      def build_object
        if params.key?(:id) && params.key?(:language)
          load_meta(params[:id])
          @item = scoper.where(parent_id: params[:id], language_id: @lang_id).first
          if @item.nil?
            @item = Solution::Folder.new
          else
            render_base_error(:method_not_allowed, 405, methods: 'GET, PUT', fired_method: 'POST')
          end
        end
      end

      def load_meta(id)
        meta = meta_scoper.find_by_id(id)
        log_and_render_404 unless meta
        meta
      end
  end
end
