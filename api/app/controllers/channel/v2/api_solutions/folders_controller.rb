module Channel::V2::ApiSolutions
  class FoldersController < ::ApiSolutions::FoldersController

    include ChannelAuthentication
    include HelperConcern

    SLAVE_ACTIONS = %w[folder_filter].freeze

    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:index, :show, :category_folders, :folder_filter]
    before_filter :channel_client_authentication, only: [:index, :show, :category_folders, :folder_filter]
    before_filter :sanitize_filter_query_params, only: [:folder_filter]
    before_filter :validate_filter_query_params, only: [:folder_filter]
    before_filter :delegator_validation, only: [:folder_filter]

    def folder_filter
      if validate_language
        @items = load_folders
        load_objects(@items) # => unless private_api?

        # => response.api_root_key = :folders if private_api?
        render '/api_solutions/folders/index'
      else
        false
      end
    end

    def self.decorator_name
      ::Solutions::FolderDecorator
    end

    private

      def load_folders
        items = params[:portal_id].present? ? scoper.portal_folders(params[:portal_id], [@lang_id]) : scoper.account_folders([@lang_id])
        items = items.folders_with_tags(params[:tags]) if params[:tags].present?
        items = items.folders_with_platforms(params[:platforms]) if params[:platforms].present?
        items.order('solution_folder_meta.position').preload(solution_folder_meta: :solution_platform_mapping).uniq
      end

      def sanitize_filter_query_params
        params[:platforms] = params[:platforms].split(',').uniq if params[:platforms].present?
        params[:tags] = params[:tags].split(',').uniq if params[:tags].present?
      end

      def validate_filter_query_params
        @constants_klass = 'SolutionConstants'.freeze
        @validation_klass = 'SolutionOmniFilterValidation'.freeze
        return unless validate_query_params
      end

      def delegator_validation
        @delegator = ApiSolutions::FolderDelegator.new(portal_id: params[:portal_id])
        return true if @delegator.valid?(action_name.to_sym)

        render_custom_errors(@delegator, true)
        false
      end
  end
end
