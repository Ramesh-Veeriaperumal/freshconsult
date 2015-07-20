module ApiDiscussions
  class CategoriesController < ApiApplicationController

    def forums
      @forums = paginate_items(load_association)
      render '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

      def feature_name
        DiscussionConstants::FEATURE_NAME
      end

      def load_object
        @item = scoper.detect { |category| category.id == params[:id].to_i }
        unless @item
          head :not_found # Do we need to put message inside response body for 404?
        end
      end

      def load_association
        @forums = @item.forums
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::CATEGORY_FIELDS))
        category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
        render_error category.errors unless category.valid?
      end

      def scoper
        create? ? current_account.forum_categories : current_account.forum_categories_from_cache
      end
  end
end
