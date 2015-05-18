module ApiDiscussions
  class CategoriesController < ApiApplicationController
    before_filter :portal_check, only: [:show]
    include Discussions::CategoryConcern
    skip_before_filter :check_privilege, :verify_authenticity_token, only: [:show]

    def forums
      @forums = paginate_items(@category.forums)
      render partial: '/api_discussions/forums/forum_list' # Need to revisit this based on eager loading associations in show
    end

    private

    def load_association
      @forums = @category.forums
    end

    def validate_params
      params[cname].permit(*(ApiConstants::CATEGORY_FIELDS.map(&:to_s)))
      category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
      render_error category.errors unless category.valid?
    end

    def portal_check
      access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
    end
  end
end
