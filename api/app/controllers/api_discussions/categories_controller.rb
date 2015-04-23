module ApiDiscussions
  class CategoriesController < ApiApplicationController
    include ApiDiscussions::Category

    before_filter { |c| c.requires_feature :forums }
    before_filter { |c| c.check_portal_scope :open_forums }
    before_filter :validate_params, :only => [:create]


    def index
       @categories = scoper.all
    end

    def create
      @forum_category = scoper.build(params[:forum_category])
      unless @forum_category.save
        format_error(@forum_category.errors)
        render :template => '/bad_request_error.json.jbuilder', :status => find_http_error_code(@errors)
      end
    end

    private 

      def validate_params
        params.require("forum_category").permit("name", "description")#created_at and updated_at needed for forum categories?
       	category = ::ApiDiscussions::CategoryValidation.new(params)
       	unless category.valid?
          format_error(category.errors)
          render :template => '/bad_request_error.json.jbuilder', :status => 400
        end
      end 
  end
end