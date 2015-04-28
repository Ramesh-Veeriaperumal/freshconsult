module ApiDiscussions
  class CategoriesController < ApiApplicationController
    include ApiDiscussions::Category

    before_filter { |c| c.requires_feature :forums }
    before_filter { |c| c.check_portal_scope :open_forums }
    before_filter :validate_params, :only => [:create]


    def index
       @categories = scoper.all.paginate(paginate_options)
    end

    def create
      @forum_category = scoper.build(params)
      unless @forum_category.save
        @errors = format_error(@forum_category.errors)
        render :template => '/bad_request_error', :status => find_http_error_code(@errors)
      end
    end

    private 

      def validate_params
        params[cname].permit("name", "description")#created_at and updated_at needed for forum categories?
       	category = ::ApiDiscussions::CategoryValidation.new(params[cname])
       	unless category.valid?
          @errors = format_error(category.errors)
          render :template => '/bad_request_error', :status => 400
        end
      end 
  end
end