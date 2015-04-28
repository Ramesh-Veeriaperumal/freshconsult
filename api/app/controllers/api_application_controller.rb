class ApiApplicationController < ApplicationController

  include ErrorHelper 	
  respond_to :json
  after_filter :latest_version

  rescue_from ActionController::UnpermittedParameters, :with => :invalid_field_handler
  rescue_from ActionController::ParameterMissing, :with => :missing_field_handler

  DEFAULT_PAGINATE_OPTIONS = {
      :per_page => 30,
      :page => 1
  }

  def latest_version
    response.headers["Latest-Version"] = "2"
  end

  def invalid_field_handler(exception)
    invalid_fields = Hash[exception.params.collect { |v| [v, "invalid_field"] }]
    render_400 invalid_fields
  end

  def missing_field_handler(exception)
    missing_fields = { exception.param => "missing_field" }
    render_400 missing_fields
  end

  def render_400 errors
    @errors = format_error(errors)
    render :template => '/bad_request_error', :status => 400
  end

  def paginate_options
    options = {}
    options[:per_page] = params[:per_page].blank? || params[:per_page].to_i > DEFAULT_PAGINATE_OPTIONS[:per_page] ?  DEFAULT_PAGINATE_OPTIONS[:per_page] : params[:per_page]
    options[:page] = params[:page] || DEFAULT_PAGINATE_OPTIONS[:page] 
    options
  end

  def cname
    controller_name.singularize
  end
end