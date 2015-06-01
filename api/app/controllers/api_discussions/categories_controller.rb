module ApiDiscussions
  class CategoriesController < ApiApplicationController
    prepend_before_filter { |c| c.requires_feature :forums }
    skip_before_filter :verify_authenticity_token, only: [:show]

    def forums
      @forums = paginate_items(@category.forums)
      render template: '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

      def load_association
        @forums = @category.forums
      end

      def validate_params
        params[cname].permit(*(ApiConstants::CATEGORY_FIELDS))
        category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
        render_error category.errors unless category.valid?
      end

      def scoper
        current_account.forum_categories
      end
  end
end
