module ApiDiscussions
  class CategoriesController < ApiApplicationController
    include ApiDiscussions::Category
    
    # before_filters related to show method is absent as show endpoint has been removed.
    before_filter :validate_params, :only => [:create, :update]
    skip_before_filter :check_privilege, :verify_authenticity_token, :only => [:show, :index]
    before_filter :portal_check, :only => [:show, :index]

    private

    def validate_params
      params.require(cname).permit("name", "description")
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