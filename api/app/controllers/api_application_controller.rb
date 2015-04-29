class ApiApplicationController < ApplicationController

  include ErrorHelper 
  respond_to :json
  prepend_before_filter :latest_version

  rescue_from ActionController::UnpermittedParameters, :with => :invalid_field_handler
  rescue_from ActionController::ParameterMissing, :with => :missing_field_handler

  DEFAULT_PAGINATE_OPTIONS = {
      :per_page => 30,
      :page => 1
  } # move to constants 


  skip_before_filter :set_default_locale, :set_locale, :freshdesk_form_builder, :remove_rails_2_flash_before,
    :remove_pjax_param, :remove_rails_2_flash_after

  skip_before_filter :check_privilege, :only => [:route_not_found]

  before_filter :build_object, :only => [ :create ]
  before_filter :load_object, :only => [ :show, :update, :destroy ]
  before_filter :load_objects, :only => [ :index ]

  def index
  end

  def create
    unless @item.save
      format_error(@item.errors)
      render :template => '/bad_request_error', :status => find_http_error_code(@errors)
    end
  end

  def show
  end

  def update
    unless @item.update_attributes(params[cname])
      format_error(@item.errors)
      render :template => '/bad_request_error', :status => find_http_error_code(@errors)
    end   
  end

  def destroy
    @item.destroy
    head :ok
  end

  def route_not_found
    method, path = env['REQUEST_METHOD'].downcase.to_sym, env['PATH_INFO']
    allows = ActionDispatch::Routing::HTTP_METHODS.select { |verb|
      begin
        match = Rails.application.routes.recognize_path(path, :method => verb)
        match[:action] != 'route_not_found'
      rescue ActionController::RoutingError
        nil
      end
    }.map(&:upcase)
    if allows.present?
      @error = ::ApiError::BaseError.new(:method_not_allowed, :methods => allows.join(", "))
      render :template => '/base_error', :status => 405
    else
      head :not_found
    end
  end

  protected

  def latest_version
    response.headers["X-Freshdesk-API-Version"] = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    # add api limit info  
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

  def access_denied
    if current_user
      @error = ::ApiError::RequestError.new(:access_denied)
      status = 403
    else
      @error = ::ApiError::RequestError.new(:invalid_credentials)
      status = 401
    end
    render :template => '/request_error', :status => status
  end

  def requires_feature(f)
    return if feature?(f)
    @error = ::ApiError::RequestError.new(:require_feature, :feature => f.to_s.titleize)
    render :template => '/request_error', :status => 403
  end
  
  def load_object
    @item = self.instance_variable_set('@' + cname,  scoper.find_by_id(params[:id]))
    unless @item
      head :not_found
    end
  end
  
  def build_object
    @item = self.instance_variable_set('@' + cname,
    scoper.is_a?(Class) ? scoper.new(params[cname]) : scoper.build(params[cname]))
  end

  def load_objects
    @items = scoper.all.paginate(paginate_options)
    self.instance_variable_set('@' + cname.pluralize, @items) 
  end
end