module ApiDiscussions
  class CategoriesController < ApiApplicationController
    include ApiDiscussions::Category
    
    # before_filters related to show method is absent as show endpoint has been removed.
    before_filter :validate_params, :only => [:create, :update]

    private

    def validate_params
      params.require(cname).permit("name", "description")
     	category = ApiDiscussions::CategoryValidation.new(params, cname, @item)
     	unless category.valid?
        format_error(category.errors)
        render :template => '/bad_request_error', :status => 400
      end
    end
  end
end