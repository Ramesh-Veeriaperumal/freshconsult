module ApiDiscussions
  class CategoriesController < ApiApplicationController
    private

      def feature_name
        FeatureConstants::DISCUSSION
      end

      def validate_params
        params[cname].permit(*(DiscussionConstants::CATEGORY_FIELDS))
        category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
        render_errors category.errors unless category.valid?
      end

      def load_objects
        # Web follows order by position. As we don't give position in response, falling back to name which is indexed.
        super(scoper.reorder(:name))
      end

      def scoper
        current_account.forum_categories
      end
  end
end
