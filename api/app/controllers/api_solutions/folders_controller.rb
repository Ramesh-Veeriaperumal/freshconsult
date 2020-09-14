module ApiSolutions
  class FoldersController < ApiApplicationController
    include SolutionConcern
    include Solution::LanguageControllerMethods
    decorate_views(decorate_objects: [:category_folders, :folder_filter])
    SLAVE_ACTIONS = %w[index category_folders].freeze
    before_filter :validate_filter_params, only: [:category_folders], unless: :channel_v2?

    def create
      return unless delegator_validation

      if create_or_update_folder
        render_201_with_location(item_id: @item.parent_id)
      else
        render_solution_item_errors
      end
    end

    def update
      return unless delegator_validation

      render_solution_item_errors unless create_or_update_folder
    end

    def destroy
      @meta.destroy
      head 204
    end

    def category_folders
      if validate_language
        @item = solution_category_meta(params[:id])
        if @item
          load_category_folders
          response.api_root_key = :folders if private_api?
          render '/api_solutions/folders/index'
        else
          log_and_render_404
        end
      else
        false
      end
    end

    private

      def scoper
        current_account.solution_folders
      end

      def meta_scoper
        current_account.solution_folder_meta.where(is_default: false)
      end

      def delegator_validation
        @delegator = ApiSolutions::FolderDelegator.new(delegator_params)
        return true if @delegator.valid?(action_name.to_sym)

        render_custom_errors(@delegator, true)
        return false
      end

      def delegator_params
        delegator_params = @folder_params.slice(:contact_folders_attributes, :company_folders_attributes, :customer_folders_attributes, :tag_attributes, :platforms, :icon_attribute)
        delegator_params[:id] = params[:id] if params[:id].present?
        delegator_params[:language_code] = params[:language] if params[:language].present?
        delegator_params
      end

      def create_or_update_folder
        @meta = Solution::Builder.folder(solution_folder_meta: @folder_params, language_id: @lang_id)
        @item = @meta.safe_send(language_scoper)
        !(@item.errors.any? || @item.parent.errors.any?)
      end

      def load_category_folders
        @items = @item.solution_folders.where(language_id: @lang_id).order('solution_folder_meta.position').preload(:solution_folder_meta)
        load_objects(@items) unless private_api?
      end

      # Load category if create endpoint is triggered with primitive language
      def load_category
        if @lang_id == current_account.language_object.id
          @item = solution_category_meta(params[:id])
          if @item.nil?
            log_and_render_404
            return false
          end
        end
        true
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
          return false unless validate_language && load_category
        end
        fields = private_api? ? SolutionConstants::FOLDER_FIELDS_PRIVATE_API : SolutionConstants::FOLDER_FIELDS
        params[cname].permit(*fields)
        folder = ApiSolutions::FolderValidation.new(params[cname], @item, @lang_id)
        render_errors folder.errors, folder.error_options unless folder.valid?(action_name.to_sym)
      end

      def sanitize_params
        prepare_array_fields [:company_ids, :contact_segment_ids, :company_segment_ids]
        language_params = params[cname].slice(:name, :description)
        params[cname][language_scoper] = language_params unless language_params.empty?
        params[cname][category] = params[:id]
        params[cname][:icon] = params[cname][:icon].to_s if params.key?(:icon)
        ParamsHelper.assign_and_clean_params({ company_ids: :customer_folders_attributes, contact_segment_ids: :contact_folders_attributes, company_segment_ids: :company_folders_attributes, tags: :tag_attributes, icon: :icon_attribute }, params[cname])
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

      def solution_category_meta(id)
        current_account.solution_category_meta.where(is_default: false, id: id).first
      end

      def validate_filter_params
        super(SolutionConstants::INDEX_FIELDS)
      end

      def channel_v2?
        self.class == Channel::V2::ApiSolutions::FoldersController
      end
  end
end
