module Ember
  module Solutions
    class FoldersController < ApiSolutions::FoldersController
      include SolutionConcern
      include HelperConcern
      include BulkActionConcern
      include SolutionBulkActionConcern

      before_filter :validate_language, only: [:index]
      before_filter :validate_bulk_update_folder_params, only: [:bulk_update]

      def bulk_update
        @succeeded_list = []
        @failed_list = []
        @folders = meta_scoper.where(id: cname_params[:ids]).preload(:solution_category_meta, :primary_folder)
        @folders.each do |folder|
          if update_folder_properties(folder)
            @succeeded_list << folder.id
          else
            @failed_list << folder
          end
        end
        render_bulk_action_response(@succeeded_list, @failed_list)
      end

      private

        def constants_class
          'SolutionsConstants'.freeze
        end

        def load_objects
          @items = fetch_folders
        end

        def render_201_with_location(template_name: "api_solutions/folders/#{action_name}", location_url: 'api_solutions_folder_url', item_id: @item.id)
          render template_name, location: safe_send(location_url, item_id), status: 201
        end

        def fetch_folders
          current_account.public_category_meta.preload(:solution_folders).map(&:solution_folders).flatten.select { |f| f.language_id == @lang_id }
        end
    end
  end
end
