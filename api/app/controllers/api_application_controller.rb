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
  before_filter :set_cache_buster
  before_filter :logging_details
  include AuthenticationSystem
  include HelpdeskSystem
  include ControllerLogger
  include SubscriptionSystem
  # ************************ App specific Before filters Ends ******************************#

  skip_before_filter :check_privilege, only: [:route_not_found]
  before_filter :load_object, except: [:create, :index, :route_not_found]
  before_filter :check_params, only: :update
  before_filter :validate_params, only: [:create, :update]
  before_filter :manipulate_params, only: [:create, :update]
  before_filter :build_object, only: [:create]
  before_filter :load_objects, only: [:index]
  before_filter :load_association, only: [:show]

  def index
    # load_objects will load all objects and index.json.jbuilder will render the result.
  end

  def create
    if @item.save
      render "#{controller_path}/create", location: send("#{nscname}_url", @item.id), status: 201
    else
      set_custom_errors
      @error_options ? render_custom_errors(@item, @error_options) : render_error(@item.errors)
    end
  end

  def show
    # load_object will load the object and show.json.jbuilder will render the result.
  end

  def update
    unless @item.update_attributes(params[cname])
      set_custom_errors # this will set @error_options if necessary.
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
    if allows.present? # route is present, but method is not allowed.
      @error = BaseError.new(:method_not_allowed, methods: allows.join(', '))
      render '/base_error', status: 405
      response.headers['Allow'] = allows.join(', ')
    else # route not present.
      head :not_found
    end
  end

  protected

    def requires_feature(f)
      return if feature?(f)
      @error = RequestError.new(:require_feature, feature: f.to_s.titleize)
      render '/request_error', status: 403
    end

  private

    def not_get_request?
      @not_get_request ||= !request.get?
    end

    def get_email_user(username, pwd)
      user = User.find_by_user_emails(username) # existing method used by authlogic to find user
      if user && !user.deleted
        valid_password = user.valid_password?(pwd) # valid_password - AuthLogic method
        if valid_password
          # reset failed_login_count only when it has changed. This is to prevent unnecessary save on user.
          update_failed_login_count(user, true) if user.failed_login_count != 0
          user
        else
          update_failed_login_count(user)
          nil
        end
      end
    end

    # This increases for each consecutive failed login.
    # See Authlogic::Session::BruteForceProtection and the consecutive_failed_logins_limit config option for more details.
    def update_failed_login_count(user, reset = false)
      if reset
        user.failed_login_count = 0
      else
        user.failed_login_count ||= 0
        user.failed_login_count += 1
      end
      user.save
    end

    # Authlogic does not change the column values if logged in by a session, cookie, or basic http auth
    def get_token_user(username)
      user = User.find_by_single_access_token(username)
      return user if user && !user.deleted && !user.blocked && user.active?
    end

    def current_user
      return @current_user if defined?(@current_user)
      if not_get_request?
        # authenticate using auth headers
        authenticate_with_http_basic do |username, password| # authenticate_with_http_basic - AuthLogic method
          @current_user = get_token_user(username) || get_email_user(username, password)
        end
      elsif current_user_session # fall back to old session based auth
        @current_user = (session.key?(:assumed_user)) ? (current_account.users.find session[:assumed_user]) : current_user_session.record
        if @current_user && @current_user.failed_login_count != 0
          update_failed_login_count(@current_user, true)
        end
      end
      @current_user
    end

    def assign_and_clean_params(params_hash)
      # Assign original fields with api params
      params_hash.each_pair do |api_field, attr_field|
        params[cname][attr_field] = params[cname][api_field] if params[cname][api_field]
      end
      clean_params(params_hash.keys)
    end

    def clean_params(params_to_be_deleted)
      # Delete the fields from params before calling build or save or update_attributes
      params_to_be_deleted.each do |field|
        params[cname].delete(field)
      end
    end

    # couldn't use dynamic forms/I18n for AR attributes translation as it may have an effect on web too.
    def rename_error_fields(fields = {})
      if @item.errors
        fields_to_be_renamed = fields.slice(*@item.errors.to_h.keys)
        fields_to_be_renamed.each_pair do |model_field, api_field|
          @item.errors.messages[api_field] = @item.errors.messages.delete(model_field)
        end
      end
    end

    def set_custom_errors
      # This is used to manipulate the model errors to a format that is acceptable.
    end

    def can_send_user? # if user_id or email of a user, is included in params, the current_user should have ability to assume that user.
      user_id = params[cname][:user_id]
      if user_id || @email
        @user = current_account.all_users.find_by_email(@email) if @email # should use user_for_email instead of find_by_email
        @user ||= current_account.all_users.find_by_id(user_id)
        render_request_error(:access_denied, 403, id: @user.id, name: @user.name) if @user && !is_allowed_to_assume?(@user)
      end
    end

    def set_cache_buster
      response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Fri, 01 Jan 1990 00:00:00 GMT'
    end

    def render_invalid_user_error
      @errors = [BadRequestError.new('user_id/email', 'invalid_user')]
      render '/bad_request_error', status: 400
    end

    def render_500(e)
      fail e if Rails.env.development? || Rails.env.test?
      Rails.logger.error("API 500 error: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
      @error = BaseError.new(:internal_error)
      render '/base_error', status: 500
    end

    def response_headers
      response.headers['X-Freshdesk-API-Version'] = "current=#{ApiConstants::API_CURRENT_VERSION}; requested=#{params[:version]}"
    end

    def invalid_field_handler(exception) # called if extra fields are present in params.
      invalid_fields = Hash[exception.params.collect { |v| [v, ['invalid_field']] }]
      render_error invalid_fields
    end

    def render_error(errors, meta = nil)
      @errors = ErrorHelper.format_error(errors, meta)
      render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
    end

    def render_request_error(code, status, params_hash = {})
      @error = RequestError.new(code, params_hash)
      render '/request_error', status: status
    end

    def render_custom_errors(item, options)
      Array.wrap(options[:remove]).each { |field| item.errors[field].clear }
      render_error item.errors, options[:meta]
    end

    def paginate_options
      options = {}
      options[:per_page] = params[:per_page].blank? || params[:per_page].to_i > ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] ? ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page] : params[:per_page]
      options[:page] = params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page]
      options[:total_entries] = options[:page] * options[:per_page]
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
      # assign already loaded account object so that it will not be queried repeatedly in model
      build_params = scoper.attribute_names.include?('account_id') ? { account: current_account } : {}
      @item = instance_variable_set('@' + cname, scoper.new(build_params.merge(params[cname])))
    end

    def load_objects(items = scoper)
      @items = items.paginate(paginate_options)
      instance_variable_set('@' + cname.pluralize, @items)
    end

    def nscname # namespaced controller name
      controller_path.gsub('/', '_').singularize
    end

    def get_fields(constant_name) # retrieves fields that strong params allows by privilege.
      constant = constant_name.constantize
      fields = constant[:all]
      constant.keys.each { |key| fields += constant[key] if privilege?(key) }
      fields
    end

    def load_association
      # This is used to load the association before the show method.
    end

    def paginate_items(item)
      item.paginate(paginate_options)
    end

    def check_params # update withut any params, is not allowed.
      render_request_error :missing_params, 400 if params[cname].blank?
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      render_request_error(:ssl_required, 403) unless request.ssl?
    end

    def manipulate_params
      # This will be used to map incoming parameters to parameters that the model would understand
    end

    def check_account_state
      render_request_error(:account_suspended, 403) unless current_account.active?
    end

    def update?
      action_name.to_s == 'update'
    end

    def create?
      action_name.to_s == 'create'
    end

    def get_user_param
      @email ? :email : :user_id
    end
end
