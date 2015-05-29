class ApiApplicationController < MetalApiController
  prepend_before_filter :response_headers
  # do not change the exception order # standard error has to have least priority hence placing at the top.
  rescue_from StandardError do |exception|
    render_500(exception)
  end
  rescue_from ActionController::UnpermittedParameters, with: :invalid_field_handler
  rescue_from DomainNotReady, with: :route_not_found

  include Concerns::ApplicationConcern

  # ************************ App specific Before filters Starts ******************************#
  # All before filters should be here. Should not be moved to concern. As the order varies for API and Web
  around_filter :select_shard
  prepend_before_filter :determine_pod
  before_filter :unset_current_account, :unset_current_portal, :set_current_account
  before_filter :ensure_proper_protocol
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :check_account_state, except: [:show, :index]
  before_filter :set_time_zone, :check_day_pass_usage
  before_filter :force_utf8_params
  include AuthenticationSystem
  include HelpdeskSystem
  include ControllerLogger
  include SubscriptionSystem
  protect_from_forgery
  before_filter :verify_authenticity_token, if: :api_request?
  # ************************ App specific Before filters Ends ******************************#

  skip_before_filter :check_privilege, only: [:route_not_found]
  before_filter :load_object, except: [:create, :index, :route_not_found]
  before_filter :check_params, only: :update
  before_filter :validate_params, only: [:create, :update]
  before_filter :manipulate_params, only: [:create, :update]
  before_filter :build_object, only: [:create]
  before_filter :load_objects, only: [:index]
  before_filter :load_association, only: [:show]

  def index; end

  def create
    if @item.save
      render template: "#{controller_path}/create", location: send("#{nscname}_url", @item.id), status: :created
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def show
  end

  def update
    unless @item.update_attributes(params[cname])
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
    allows = ActionDispatch::Routing::HTTP_METHODS.select do |verb|
      match = Rails.application.routes.recognize_path(path, method: verb)
      match[:action] != 'route_not_found'
    end.map(&:upcase)
    if allows.present?
      @error = BaseError.new(:method_not_allowed, methods: allows.join(', '))
      render template: '/base_error', status: 405
      response.headers['Allow'] = allows.join(', ')
    else
      head :not_found
    end
  end

  protected

    def requires_feature(f)
      return if feature?(f)
      @error = RequestError.new(:require_feature, feature: f.to_s.titleize)
      render template: '/request_error', status: 403
    end

  private

    def set_custom_errors
    end

    def can_send_user?
      user_id = params[cname][:user_id]
      if user_id || @email
        @user = current_account.all_users.find_by_email(@email) if @email
        @user ||= current_account.all_users.find_by_id(user_id)
        render_invalid_user_error if @user && !is_allowed_to_assume?(@user)
      end
    end

    def render_invalid_user_error
      @errors = [BadRequestError.new('user_id/email', 'invalid_user')]
      render template: '/bad_request_error', status: 400
    end

    def render_500(e)
      fail e if Rails.env.development? || Rails.env.test?
      Rails.logger.debug("API 500 error: #{params} \n#{e.message}\n#{e.backtrace.join("\n")}")
      @error = BaseError.new(:internal_error)
      render template: '/base_error', status: 500
    end

    def response_headers
      response.headers['X-Freshdesk-API-Version'] = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    end

    def invalid_field_handler(exception)
      invalid_fields = Hash[exception.params.collect { |v| [v, 'invalid_field'] }]
      render_error invalid_fields
    end

    def render_error(errors, meta = nil)
      @errors = ErrorHelper.format_error(errors, meta)
      render template: '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
    end

    def render_request_error(code, status)
      @error = RequestError.new(code)
      render template: '/request_error', status: status
    end

    def render_custom_errors(item, options)
      errors = item.errors.reject { |k, v| k == options[:remove] } if options[:remove]
      render_error errors, options[:meta]
    end

    def paginate_options
      options = {}
      options[:per_page] = params[:per_page].blank? || params[:per_page].to_i > ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] ? ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] : params[:per_page]
      options[:page] = params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page]
      options
    end

    def cname
      controller_name.singularize
    end

    def access_denied
      if current_user
        render_request_error :access_denied, 403
      else
        render_request_error :invalid_credentials, 401
      end
    end

    def load_object
      @item = instance_variable_set('@' + cname,  scoper.find_by_id(params[:id]))
      unless @item
        head :not_found # Do we need to put message inside response body for 404?
      end
    end

    def build_object
      @item = instance_variable_set('@' + cname, scoper.new(params[cname]))
    end

    def load_objects
      @items = scoper.all.paginate(paginate_options)
      instance_variable_set('@' + cname.pluralize, @items)
    end

    def nscname
      controller_path.gsub('/', '_').singularize
    end

    def get_fields(constant_name)
      constant = constant_name.constantize
      fields = constant[:all]
      constant.keys.each { |key| fields += constant[key] if privilege?(key) }
      fields
    end

    def load_association
    end

    def paginate_items(item)
      item.paginate(paginate_options)
    end

    def check_params
      render_request_error :missing_params, 400 if params[cname].blank?
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      render_request_error(:ssl_required, 403) unless request.ssl?
    end

    def manipulate_params
    end

    def check_account_state
      render_request_error(:account_suspended, 403) unless current_account.active?
    end

    def handle_unverified_request
      super
      post_process_unverified_request
      render_request_error(:unverified_request, 401)
    end
end
