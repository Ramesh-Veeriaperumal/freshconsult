module ApiDiscussions
  class CategoriesController < ApiApplicationController
    before_filter :portal_check, :only => [:show, :index]
    include ApiDiscussions::Category
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show]

    private

      def validate_params
        params[cname].permit(*(ApiConstants::CATEGORY_FIELDS.map(&:to_s)))
       	category = ApiDiscussions::CategoryValidation.new(params[cname], @item)
       	unless category.valid?
          @errors = format_error(category.errors)
          render :template => '/bad_request_error', :status => 400
        end
      end

      def portal_check
        access_denied if current_user.nil? || current_user.customer? || !privilege?(:view_forums)
      end
  end
end