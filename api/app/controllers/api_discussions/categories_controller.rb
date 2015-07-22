module ApiDiscussions
  class CategoriesController < ApiApplicationController

    def forums
      @forums = paginate_items(load_association)
      render '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

      def feature_name
        FeatureConstants::DISCUSSION
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
        current_account.forum_categories
      end
  end
end
