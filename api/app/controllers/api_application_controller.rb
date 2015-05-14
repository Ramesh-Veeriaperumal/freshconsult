class ApiApplicationController < ApplicationController
  
  respond_to :json
  prepend_before_filter :response_headers

  # do not change the exception order # standard error has to have least priority hence placing at the top.
  rescue_from StandardError do |exception| 
    render_500(exception)  
  end
  rescue_from ActionController::UnpermittedParameters, :with => :invalid_field_handler
  rescue_from ActionController::ParameterMissing, :with => :missing_field_handler

  skip_before_filter :set_default_locale, :set_locale, :freshdesk_form_builder, :remove_rails_2_flash_before,
    :remove_pjax_param, :remove_rails_2_flash_after

  skip_before_filter :check_privilege, :only => [:route_not_found]
  before_filter :load_object, :only => [ :show, :update, :destroy ]
  before_filter :check_params, :only => :update
  before_filter :validate_params, :only => [:create, :update]
  before_filter :manipulate_params, :only => [:create, :update]
  before_filter :build_object, :only => [ :create ]
  before_filter :load_objects, :only => [ :index ]
  before_filter :load_association, :only => [:show]

  # wrap params will wrap only attr_accessible fields if this is removed.
  def self.inherited(subclass)
    subclass.wrap_parameters :exclude => []
  end

  def index
  end

  def create
    if @item.save
      render :template => "#{controller_path}/create", :location => send("#{nscname}_url", @item.id), :status => :created
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)      
    end
  end

  def show
  end

  def update
    if @item.update_attributes(params[cname])
      render :template => "#{controller_path}/update",  :status => :ok
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)      
    end 
  end

  def destroy
    @item.destroy
    head :no_content
  end

  def route_not_found
    path = env['PATH_INFO']
    allows = ActionDispatch::Routing::HTTP_METHODS.select { |verb|
      match = Rails.application.routes.recognize_path(path, :method => verb)
      match[:action] != 'route_not_found'
    }.map(&:upcase)
    if allows.present?
      @error = BaseError.new(:method_not_allowed, :methods => allows.join(", "))
      render :template => '/base_error', :status => 405
      response.headers["Allow"] = allows.join(", ")
    else
      head :not_found
    end
  end

  protected

    def requires_feature(f)
      return if feature?(f)
      @error = RequestError.new(:require_feature, :feature => f.to_s.titleize)
      render :template => '/request_error', :status => 403
    end
    
  private
    def set_custom_errors
    end

    def render_500(e)
      raise e if Rails.env.development? || Rails.env.test?
      Rails.logger.debug("API 500 error: #{params} \n#{e.message}\n#{e.backtrace.join("\n")}")
      @error = BaseError.new(:internal_error)
      render :template => '/base_error', :status => 500
    end

    def response_headers
      response.headers["X-Freshdesk-API-Version"] = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    end

    def invalid_field_handler(exception)
      invalid_fields = Hash[exception.params.collect { |v| [v, "invalid_field"] }]
      render_error invalid_fields
    end

    def missing_field_handler(exception)
      missing_fields = { exception.param => "missing_field" }
      render_error missing_fields
    end

    def render_error errors, meta = nil
      @errors = ErrorHelper.format_error(errors, meta)
      render :template => '/bad_request_error', :status => ErrorHelper.find_http_error_code(@errors)
    end

    def render_custom_errors item, options
      errors = item.errors.reject{|k,v| k == options[:remove]} if options[:remove]
      render_error errors, options[:meta]
    end

    def paginate_options
      options = {}
      options[:per_page] = params[:per_page].blank? || params[:per_page].to_i > ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] ?  ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] : params[:per_page]
      options[:page] = params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page] 
      options
    end

    def cname
      controller_name.singularize
    end

    def access_denied
      if current_user
        @error = RequestError.new(:access_denied)
        status = 403
      else
        @error = RequestError.new(:invalid_credentials)
        status = 401
      end
      render :template => '/request_error', :status => status
    end
    
    def load_object
      @item = self.instance_variable_set('@' + cname,  scoper.find_by_id(params[:id]))
      unless @item
        head :not_found # Do we need to put message inside response body for 404?
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

    def nscname
      controller_path.gsub('/', '_').singularize
    end

    def get_fields(constant_name)
      constant = constant_name.constantize
      fields = constant[:all] 
      constant.keys.each{|key| fields += constant[key] if privilege?(key)}
      fields
    end

    def load_association
    end

    def check_params
      if params[cname].blank?
        @error = RequestError.new(:missing_params)
        render :template => '/request_error', :status => 400
      end
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      unless request.ssl?
        @error = RequestError.new(:ssl_required)
        render :template => '/request_error', :status => 403
      end
    end

    def manipulate_params
    end
end