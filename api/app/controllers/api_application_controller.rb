class ApiApplicationController < MetalApiController
  prepend_before_filter :response_info
  # do not change the exception order # standard error has to have least priority hence placing at the top.
  rescue_from StandardError, with: :render_500
  rescue_from ActionController::UnpermittedParameters, with: :invalid_field_handler
  rescue_from DomainNotReady, with: :route_not_found
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::StatementInvalid, with: :db_query_error
  rescue_from RangeError, with: :range_error

  # Do not change the order as record_not_unique is inheriting from statement invalid error
  rescue_from ActiveRecord::RecordNotUnique, with: :duplicate_value_error

  # Check if content-type is appropriate for specific endpoints.
  # This check should be done before any app specific filter starts.
  before_filter :validate_content_type

  include Concerns::ApplicationConcern

  # App specific Before filters Starts
  # All before filters should be here. Should not be moved to concern. As the order varies for API and Web
  around_filter :select_shard
  before_filter :current_shard # should happen first within around filter.
  prepend_before_filter :determine_pod
  before_filter :unset_current_account, :unset_current_portal, :set_current_account
  before_filter :ensure_proper_fd_domain, :ensure_proper_protocol
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :check_account_state
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

  # Redefine below method in your controllers to check strong parameters and other validations that do not require a DB call.
  before_filter :validate_params, only: [:create, :update]

  # Manipulating the parameters similar to the attributes that the model understands.
  before_filter :sanitize_params, only: [:create, :update]

  # This is not moved inside create because, controlelrs redefining create needn't call build_object again.
  before_filter :before_build_object, :build_object, only: [:create]

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
    render_custom_errors unless @item.update_attributes(params[cname])
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
      render_base_error(:method_not_allowed, 405, methods: allows.join(', '))
      response.headers['Allow'] = allows.join(', ')
    else # route not present.
      head :not_found
    end
  end

  protected

    def requires_feature(f) # Should be from cache. Need to revisit.
      return if Account.current.features?(f)
      render_request_error(:require_feature, 403, feature: f.to_s.titleize)
    end

  private

    def response_info
      RequestStore.store[:extra_credits] = 0
    end

    def render_500(e)
      fail e if Rails.env.development? || Rails.env.test?
      notify_new_relic_agent(e, description: 'Error occured while processing api request')
      Rails.logger.error("API 500 error: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
      render_base_error(:internal_error, 500)
    end

    def duplicate_value_error(e)
      notify_new_relic_agent(e, description: 'Duplicate Record Error.')
      Rails.logger.error("Duplicate Entry Error: #{params.inspect} \n#{e.original_exception} \n#{e.message}\n#{e.backtrace.join("\n")}")
      render_request_error(:duplicate_value, 409)
    end

    def range_error(e)
      # http://ruby-doc.org/core-2.1.0/RangeError.html
      # https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/page_number.rb#L18
      # We are rescuing the exception without validating in order to avoid manipulations in every request to validate a rare scenario.
      if e.message.starts_with?('invalid offset') && params[:page].respond_to?(:to_i) && params[:page].to_i > ApiConstants::PAGE_MAX
        # raised by will_paginate gem
        render_errors [[:page, :gt_zero_lt_max_per_page]]
      else
        # unexpected exception
        notify_new_relic_agent(e, description: 'Invalid Offset Error.')
        render_base_error(:internal_error, 500)
      end
      Rails.logger.error("Invalid Offset Error: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
    end

    def db_query_error(e)
      notify_new_relic_agent(e, description: 'Invalid/malformed query error occured while processing api request')
      Rails.logger.error("DB Query Invalid Error: #{params.inspect} \n#{e.message} \n#{e.backtrace.join("\n")}")
      render_base_error(:internal_error, 500)
    end

    def record_not_found(e)
      # Render 404 if domain is not present else 500.
      # our locally cached current_shard will be nil if specific domain doesn't belongs to any shards
      if current_shard.nil?
        Rails.logger.error("API V2 request for invalid host. Host: #{request.host}")
        head 404 
      else
        notify_new_relic_agent(e, description: 'ActiveRecord::RecordNotFound error occured while processing api request')
        Rails.logger.error("Record not found error. Domain: #{request.domain} \n params: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
        render_base_error(:internal_error, 500)
      end
    end

    # Caching current_shard_selection in local instance variable to find out domain not found error.
    # As exception ensures connection to be switched to initial shard.
    def current_shard
      return @current_shard if defined?(@current_shard)
      @current_shard ||= Thread.current[:shard_selection].try(:shard)
    end

    def invalid_field_handler(exception) # called if extra fields are present in params.
      return if handle_invalid_multipart_form_data(exception.params) || handle_invalid_parseable_json(exception.params)
      Rails.logger.error("API Unpermitted Parameters. Params : #{params.inspect} Exception: #{exception.class}  Exception Message: #{exception.message}")
      inaccessible_fields = @all_fields ? (@all_fields.flat_map(&:last) & exception.params) - @fields : []
      invalid_fields = exception.params - inaccessible_fields
      errors = Hash[invalid_fields.map { |v| [v, :invalid_field] } + inaccessible_fields.map { |v| [v, :inaccessible_field] }]
      render_errors errors
    end

    def handle_invalid_multipart_form_data(exception_params)
      return false unless request.raw_post == exception_params.join && request.headers['CONTENT_TYPE'] =~ /multipart\/form-data/
      render_request_error :invalid_multipart, 400
      true
    end

    def handle_invalid_parseable_json(exception_params)
      return false unless exception_params.join == '_json'
      render_request_error :invalid_json, 400
      true
    end

    def ensure_proper_fd_domain # 404
      return true if Rails.env.development?
      head 404 unless ApiConstants::ALLOWED_DOMAIN == request.domain && current_account.full_domain != ApiConstants::DEMOSITE_URL # API V2 not permitted on Demosites
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      render_request_error(:ssl_required, 403) unless request.ssl?
    end

    def render_request_error(code, status, params_hash = {})
      @error = RequestError.new(code, params_hash)
      render '/request_error', status: status
    end

    def render_base_error(code, status, params_hash = {})
      @error = BaseError.new(code, params_hash)
      render '/base_error', status: status
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

    def validate_content_type
      unless get_request? || request.delete? || valid_content_type?
        render_request_error :invalid_content_type, 415
      end
    end

    def before_build_object
      # Template method to stop execution just before build_object
    end

    def before_load_object
      # Template method to stop execution just before load_object
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id])
      unless @item
        head 404 # Do we need to put message inside response body for 404?
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

    def prepare_array_fields(array_fields = [])
      array_fields.each do |array_field|
        array_field = array_field.to_sym
        if create? || params[cname].key?(array_field)
          array_value = Array.wrap params[cname][array_field]
          params[cname][array_field] = array_value.uniq.reject(&:blank?)
        end
      end
    end

    def build_object
      # assign already loaded account object so that it will not be queried repeatedly in model
      account_included = scoper.attribute_names.include?('account_id')
      build_params = account_included ? { account: current_account } : {}
      @item = scoper.new(build_params.merge(params[cname]))

      # assign account separately if it is protected_attribute.
      @item.account = current_account if account_included
    end

    def validate_filter_params(additional_fields = [])
      # This method has been overridden by index actions that have filters on them.
      # The respective filter validation classes would inherit from FilterValidation to include validations on pagination options.
      params.permit(*ApiConstants::DEFAULT_INDEX_FIELDS, *additional_fields)
      @filter = FilterValidation.new(params, nil, true)
      render_query_param_errors(@filter.errors, @filter.error_options) unless @filter.valid?
    end

    def validate_url_params
      # Template method - If embedding is present in show action, this can be used to validate
      # the imput sent using strong params and custom validations.
    end

    # will take scoper as one argument.
    def load_objects(items = scoper)
      @items = paginate_items(items)
    end

    # will take items as one argument and is_array (whether scoper is a AR or array as another argument.)
    def paginate_items(items)
      is_array = !items.respond_to?(:scoped) # check if it is array or AR
      paginated_items = items.paginate(paginate_options(is_array))

      # next page exists if scoper is array & next_page is not nil or
      # next page exists if scoper is AR & collection length > per_page
      next_page_exists = paginated_items.length > @per_page || paginated_items.next_page && is_array
      add_link_header(page: (get_page + 1)) if next_page_exists
      paginated_items[0..(@per_page - 1)] # get paginated_collection of length 'per_page'
    end

    # Add link header if next page exists.
    def add_link_header(query_parameters)
      response.headers['Link'] = construct_link_header(query_parameters)
    end

    # Construct link header for paginated collection
    def construct_link_header(updated_query_parameters)
      query_string = '?'

      # Construct query string with updated_query_parameters.
      request.query_parameters.merge(updated_query_parameters).each { |x, y| query_string += "#{x}=#{y}&" }
      url = url_for(only_path: false) + query_string.chop # concatenate url & chopped query string
      "<#{url}>; rel=\"next\""
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

    def render_custom_errors(item = @item, merge_item_error_options = false)
      options = set_custom_errors(item) # this will set @error_options if necessary.

      # Remove raw errors from model if remove option specified
      Array.wrap(options.delete(:remove)).each { |field| item.errors[field].clear } if options

      # Rename keys in error_options if error_options_mappings exists
      if merge_item_error_options && item.error_options
        ErrorHelper.rename_keys(error_options_mappings, item.error_options)
        (options ||= {}).merge!(item.error_options)
      end
      render_errors(item.errors, options)
    end

    # Error options field mappings to rename the keys Say, agent in ticket error will be replaced with responder_id
    def error_options_mappings
      {}
    end

    def render_query_param_errors(errors, meta = nil)
      set_query_param_errors(errors)
      render_errors(errors, meta)
    end

    def set_query_param_errors(errors)
      # this will translate generic positive_number error to specific per_page_positive_number 
      # this is being done to get different custom codes with the same error message.
      errors[:per_page] = "per_page_#{errors.to_h[:per_page]}" if errors[:per_page].present?
    end

    def render_errors(errors, meta = nil)
      if errors.present?
        @errors = ErrorHelper.format_error(errors, meta)
        render '/bad_request_error', status: ErrorHelper.find_http_error_code(@errors)
      else
        # before_callbacks may return false without populating the errors hash.
        Rails.logger.error("API Error Hash empty :: Params: #{params.inspect}")
        notify_new_relic_agent(StandardError, description: 'API Error Hash empty', params: params)
        render_base_error(:internal_error, 500)
      end
    end

    def cname
      controller_name.singularize
    end

    def access_denied
      if api_current_user
        render_request_error :access_denied, 403
      else
        render_request_error :invalid_credentials, 401
      end
    end

    def api_current_user
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

    def qualify_for_day_pass? # this method is redefined because of api_current_user
      api_current_user && api_current_user.occasional_agent? && !current_account.subscription.trial? && !is_assumed_user?
    end

    def check_privilege # this method is redefined because of api_current_user
      if api_current_user.nil? || api_current_user.customer? || !allowed_to_access?
        access_denied
        return false
      end
      true
    end

    def allowed_to_access? # this method is redefined because of api_current_user
      return false unless ABILITIES.key?(resource)

      ABILITIES[resource].each do |privilege|
        if [:all, action].include? privilege.action
          return true if api_current_user.privilege?(privilege.name) ||
                         api_current_user.owns_object?(privilege.load_object(current_account, params))
        end
      end

      false
    end

    def set_current_account # this method is redefined because of api_current_user
      current_account.make_current
      User.current = api_current_user
    rescue ActiveRecord::RecordNotFound
      Rails.logger.error("API V2 request for invalid account. Host: #{request.host}")
      head 404
    rescue ActiveSupport::MessageVerifier::InvalidSignature # Authlogic throw this error if signed_cookie is tampered.
      render_request_error :credentials_required, 401
    end

    def get_request?
      @get_request ||= request.get?
    end

    def can_send_user? # if user_id or email of a user, is included in params, the api_current_user should have ability to assume that user.
      user_id = params[cname][:user_id]
      email = params[cname][:email]
      if user_id || email
        @user = current_account.user_emails.user_for_email(email) if email # should use user_for_email instead of find_by_email
        @user ||= current_account.all_users.find_by_id(user_id)
        if @user && @user != api_current_user && !is_allowed_to_assume?(@user)
          render_request_error(:invalid_user, 403, id: @user.id, name: @user.name)
          return false
        end
      end
      true
    end

    def paginate_options(is_array = false)
      options = {}
      @per_page = get_per_page # user given/defualt page number
      options[:per_page] =  is_array ? @per_page : @per_page + 1 # + 1 to find next link unless scoper is array
      options[:offset] = @per_page * (get_page - 1) unless is_array # assign offset unless scoper is array
      options[:page] = get_page
      options[:total_entries] = options[:page] * options[:per_page] unless is_array # To prevent paginate from firing count query unless scoper is array
      options
    end

    def get_page
      (params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page]).to_i
    end

    def get_per_page
      (params[:per_page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).to_i
    end

    def get_fields(constant_name) # retrieves fields that strong params allows by privilege.
      constant = constant_name.constantize
      get_fields_from_constant(constant)
    end

    def get_fields_from_constant(constant, item = @item)
      # all_fields is used to differentiate between junk fields and inaccessible_fields in invalid_field_handler.
      # all_fields should not be modified as it a reference to the constant and not a separate object.
      # item is sent to privilege to accomodate owned_by privileges.
      @all_fields = constant
      @fields = constant[:all] || []
      constant.except(:all).keys.each { |key| @fields += constant[key] if privilege?(key, item) }
      @fields
    end

    def update?
      @update ||= current_action?('update')
    end

    def create?
      @create ||= current_action?('create')
    end

    def show?
      @show ||= current_action?('show')
    end

    def destroy?
      @destroy ||= current_action?('destroy')
    end

    def index?
      @index ||= current_action?('index')
    end

    def current_action?(action)
      action_name.to_s == action
    end

    def string_request_params?
      @string_request_params ||= (request.content_type.try(:include?, 'multipart/form-data') || get_request? || request.delete?)
      @string_request_params
    end

    def json_request?
      @json_request ||= request.content_mime_type.try(:ref) == :json
    end

    def valid_content_type?
      return true if request.content_mime_type.nil?
      json_request?
    end

    def set_time_zone
      Time.zone = ApiConstants::UTC
    end

    def notify_new_relic_agent(exception, custom_params = {})
      options_hash =  { uri: request.original_url, custom_params: custom_params.merge(method: request.method, params: params, x_request_id: request.uuid) }
      NewRelic::Agent.notice_error(exception, options_hash)
    end

    def increment_api_credit_by(value)
      RequestStore.store[:extra_credits] += value
    end
end
