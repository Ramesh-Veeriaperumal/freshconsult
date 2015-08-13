class ApiApplicationController < MetalApiController
  prepend_before_filter :response_headers
  # do not change the exception order # standard error has to have least priority hence placing at the top.
  rescue_from StandardError do |exception|
    render_500(exception)
  end
  rescue_from ActionController::UnpermittedParameters, with: :invalid_field_handler
  rescue_from DomainNotReady, with: :route_not_found

  include Concerns::ApplicationConcern

  # App specific Before filters Starts
  # All before filters should be here. Should not be moved to concern. As the order varies for API and Web
  around_filter :select_shard
  prepend_before_filter :determine_pod
  before_filter :unset_current_account, :unset_current_portal, :set_current_account
  before_filter :ensure_proper_fd_domain, :ensure_proper_protocol
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :check_account_state, except: [:show, :index]
  before_filter :set_time_zone, :check_day_pass_usage
  before_filter :force_utf8_params
  before_filter :set_cache_buster
  before_filter :logging_details
  include AuthenticationSystem
  include HelpdeskSystem
  include ControllerLogger
  include SubscriptionSystem
  # App specific Before filters Ends

  before_filter { |c| c.requires_feature feature_name if feature_name }
  skip_before_filter :check_privilege, only: [:route_not_found]

  # before_load_object and after_load_object are used to stop the execution exactly before and after the load_object call.
  # Modify ApiConstants::LOAD_OBJECT_EXCEPT to include any new methods introduced in the controller that does not require load_object.
  before_filter :before_load_object, :load_object, :after_load_object, except: ApiConstants::LOAD_OBJECT_EXCEPT

  # Used to check if update contains no parameters.
  before_filter :check_params, only: :update

  # Used to stop execution of create before validating the params.
  before_filter :before_validation, only: [:create]

  # Redefine below method in your controllers to check strong parameters and other validations that do not require a DB call.
  before_filter :validate_params, only: [:create, :update]

  # Manipulating the parameters similar to the attributes that the model understands.
  before_filter :sanitize_params, only: [:create, :update]

  # This is not moved inside create because, controlelrs redefining create needn't call build_object again.
  before_filter :build_object, only: [:create]

  # Validating the filter params sent in the url for filtering collection of objects.
  before_filter :validate_filter_params, only: [:index]

  before_filter :validate_url_params, only: [:show]

  def index
    load_objects
  end

  def create
    assign_protected
    if @item.save
      render_201_with_location
    else
      render_custom_errors
    end
  end

  def show
    # load_object will load the object and show.json.jbuilder will render the result.
  end

  def update
    assign_protected
    unless @item.update_attributes(params[cname])
      render_custom_errors
    end
  end

  def destroy
    @item.destroy
    head :no_content
  end

  def route_not_found
    path = env['PATH_INFO']
    Rails.logger.error("API 404 Error. Path: #{path} Params: #{params.inspect}")
    allows = ActionDispatch::Routing::HTTP_METHODS.select do |verb|
      match = Rails.application.routes.recognize_path(path, method: verb)
      match[:action] != 'route_not_found'
    end.map(&:upcase)
    if allows.present? # route is present, but method is not allowed.
      @error = BaseError.new(:method_not_allowed, methods: allows.join(', '))
      render '/base_error', status: 405
      response.headers['Allow'] = allows.join(', ')
    else # route not present.
      head :not_found
    end
  end

  protected

    def requires_feature(f) # Should be from cache. Need to revisit.
      return if current_account.features_included?(f)
      @error = RequestError.new(:require_feature, feature: f.to_s.titleize)
      render '/request_error', status: 403
    end

  private

    def response_headers
      response.headers['X-Freshdesk-API-Version'] = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    end

    def render_500(e)
      fail e if Rails.env.development? || Rails.env.test?
      Rails.logger.error("API 500 error: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
      @error = BaseError.new(:internal_error)
      render '/base_error', status: 500
    end

    def invalid_field_handler(exception) # called if extra fields are present in params.
      Rails.logger.error("API Unpermitted Parameters Error. Params : #{params.inspect} Exception: #{exception.class}  Exception Message: #{exception.message}")
      invalid_fields = Hash[exception.params.collect { |v| [v, ['invalid_field']] }]
      render_errors invalid_fields
    end

    def ensure_proper_fd_domain # 404
      return true if Rails.env.development?
      head 404 unless ApiConstants::ALLOWED_DOMAIN == request.domain
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      render_request_error(:ssl_required, 403) unless request.ssl?
    end

    def render_request_error(code, status, params_hash = {})
      @error = RequestError.new(code, params_hash)
      render '/request_error', status: status
    end

    def check_account_state
      render_request_error(:account_suspended, 403) unless current_account.active?
    end

    def set_cache_buster
      response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Wed, 13 Oct 2010 00:00:00 UTC'
    end

    def feature_name
      # Template method - Redefine if the controller needs requires_feature before_filter
    end

    def before_load_object
      # Template method to stop execution just before load_object
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id])
      unless @item
        head :not_found # Do we need to put message inside response body for 404?
      end
    end    

    def after_load_object
      # Template method to stop execution immediately after load_object
    end

    def check_params # update withut any params, is not allowed.
      render_request_error :missing_params, 400 if params[cname].blank?
    end

    def before_validation
      # Template method - can be used to limit the parameters sent based on the permissions of the user before creating.
    end

    def validate_params
      # Redefine below method in your controllers to check strong parameters and other validations that do not require a DB call.
    end

    def sanitize_params
      # This will be used to map incoming parameters to parameters that the model would understand
    end

    def build_object
      # assign already loaded account object so that it will not be queried repeatedly in model
      build_params = scoper.attribute_names.include?('account_id') ? { account: current_account } : {}
      @item = scoper.new(build_params.merge(params[cname]))
    end

    def validate_filter_params
      # Template method - If filtering is present in index action, this can be used to validate
      # each filter and its value using strong params and custom validation classes.
    end

    def validate_url_params
      # Template method - If embedding is present in show action, this can be used to validate
      # the imput sent using strong params and custom validations.
    end

    def load_objects(items = scoper)
      @items = items.paginate(paginate_options)
    end

    def assign_protected
      # Template method - Assign attributes that cannot be mass assigned.
    end

    # Using optional parameters for extensibility
    def render_201_with_location(template_name: "#{controller_path}/#{action_name}", location_url: "#{nscname}_url", item_id: @item.id)
      render template_name, location: send(location_url, item_id), status: 201
    end

    def nscname # namespaced controller name
      controller_path.gsub('/', '_').singularize
    end

    def set_custom_errors(_item = @item)
      # This is used to manipulate the model errors to a format that is acceptable.
    end

    def render_custom_errors(item = @item)
      options = set_custom_errors(item) # this will set @error_options if necessary.
      Array.wrap(options.delete(:remove)).each { |field| item.errors[field].clear } if options
      render_errors(item.errors, options)
    end

    def render_errors(errors, meta = nil)
      @errors = ErrorHelper.format_error(errors, meta)
      render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
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

    def current_user
      return @current_user if defined?(@current_user)
      if get_request?
        if current_user_session # fall back to old session based auth
          @current_user = (session.key?(:assumed_user)) ? (current_account.users.find session[:assumed_user]) : current_user_session.record
          if @current_user && @current_user.failed_login_count != 0
            @current_user.update_failed_login_count(true)
          end
        end
      else
        # authenticate using auth headers
        authenticate_with_http_basic do |username, password| # authenticate_with_http_basic - AuthLogic method
          # string check for @ is used to avoid a query.
          @current_user = username.include?('@') ? AuthHelper.get_email_user(username, password, request.ip) : AuthHelper.get_token_user(username)
        end
      end
      @current_user
    end

    def get_request?
      @get_request ||= request.get?
    end

    def can_send_user? # if user_id or email of a user, is included in params, the current_user should have ability to assume that user.
      user_id = params[cname][:user_id]
      email = params[cname][:email]
      if user_id || email
        @user = current_account.user_emails.user_for_email(email) if email # should use user_for_email instead of find_by_email
        @user ||= current_account.all_users.find_by_id(user_id)
        if @user && @user != current_user && !is_allowed_to_assume?(@user)
          render_request_error(:invalid_user, 403, id: @user.id, name: @user.name)
          return false
        end
      end
      true
    end

    def paginate_items(item)
      item.paginate(paginate_options)
    end

    def paginate_options
      options = {}
      options[:per_page] = get_per_page
      options[:page] = params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page]
      options[:total_entries] = options[:page] * options[:per_page] # To prevent paginate from firing count query
      options
    end

    def get_per_page
      if params[:per_page].blank?
        ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]
      else
        [params[:per_page], ApiConstants::DEFAULT_PAGINATE_OPTIONS[:max_per_page]].min
      end
    end

    def get_fields(constant_name) # retrieves fields that strong params allows by privilege.
      constant = constant_name.constantize
      fields = constant[:all]
      constant.keys.each { |key| fields += constant[key] if privilege?(key) }
      fields
    end

    def update?
      @update ||= action_name == 'update'
    end

    def create?
      @create ||= action_name == 'create'
    end

    def show?
      @show ||= action_name == 'show'
    end

    def destroy?
      @destroy ||= action_name == 'destroy'
    end
end
