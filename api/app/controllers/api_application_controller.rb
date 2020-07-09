class ApiApplicationController < MetalApiController
  # account suspended restricted methods.
  RESTRICTED_ACCESS_METHODS = [:post, :put, :delete]
  prepend_before_filter :response_info
  # do not change the exception order # standard error has to have least priority hence placing at the top.
  rescue_from StandardError, with: :render_500
  rescue_from ActionController::UnpermittedParameters, with: :invalid_field_handler
  rescue_from ShardNotFound, with: :record_not_found
  rescue_from DomainNotReady, with: :record_not_found
  # rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  # rescue_from ActiveRecord::StatementInvalid, with: :db_query_error
  rescue_from RangeError, with: :range_error

  protect_from_forgery
  skip_before_filter :verify_authenticity_token
  before_filter :unset_thread_variables
  around_filter :log_csrf
  before_filter :verify_authenticity_token, if: :csrf_check_reqd?

  # Do not change the order as record_not_unique is inheriting from statement invalid error
  # rescue_from ActiveRecord::RecordNotUnique, with: :duplicate_value_error
  rescue_from Mysql2::Error, with: :activerecord_error_handler

  rescue_from ConsecutiveFailedLoginError, with: :login_error_handler

  # Check if content-type is appropriate for specific endpoints.
  # This check should be done before any app specific filter starts.
  before_filter :validate_content_type

  include Concerns::ApplicationConcern

  # App specific Before filters Starts
  # All before filters should be here. Should not be moved to concern. As the order varies for API and Web
  around_filter :select_shard
  prepend_before_filter :determine_pod

  around_filter :run_on_slave, if: :on_slave?
  around_filter :supress_logs, if: :can_supress_logs?

  before_filter :unset_current_portal, :unset_shard_for_payload, :unset_current_languge, :set_current_account, :set_shard_for_payload
  before_filter :ensure_proper_fd_domain, :ensure_proper_protocol, unless: :private_api?
  before_filter :authenticate_jwt_request, if: :app_authorization?
  include Authority::FreshdeskRails::ControllerHelpers
  before_filter :check_account_state, :set_default_locale, :set_current_ip
  before_filter :set_locale, if: :private_api?
  before_filter :set_time_zone, :check_day_pass_usage_with_user_time_zone, :set_msg_id
  before_filter :force_utf8_params
  before_filter :set_cache_buster
  before_filter :set_service_worker, if: :private_api?
  before_filter :check_session_timeout, if: :session_timeout_allowed?

  include AuthenticationSystem
  include HelpdeskSystem
  include SubscriptionSystem
  include Mobile::MobileHelperMethods

  include DataVersioning::Controller
  include Helpdesk::ToggleEmailNotification

  # App specific Before filters Ends

  include DecoratorConcern

  before_filter { |c| c.requires_feature(*feature_name) if feature_name }
  before_filter { |c| c.requires_feature(*launch_party_name) if launch_party_name }
  skip_before_filter :check_privilege, only: [:route_not_found]

  # before_load_object and after_load_object are used to stop the execution exactly before and after the load_object call.
  # Modify ApiConstants::LOAD_OBJECT_EXCEPT to include any new methods introduced in the controller that does not require load_object.
  before_filter :before_load_object, :load_object, :after_load_object, except: ApiConstants::LOAD_OBJECT_EXCEPT

  # Used to check if update contains no parameters.
  before_filter :check_params, only: :update

  before_filter :remove_ignore_params, only: [:create, :update], unless: :private_api?

  # Redefine below method in your controllers to check strong parameters and other validations that do not require a DB call.
  before_filter :validate_params, only: [:create, :update]

  # Manipulating the parameters similar to the attributes that the model understands and escape/sanitize(HTML/CSS) in request params.
  before_filter :sanitize_params, only: [:create, :update]

  # This is not moved inside create because, controlelrs redefining create needn't call build_object again.
  before_filter :before_build_object, :build_object, only: [:create]

  # Validating the filter params sent in the url for filtering collection of objects.
  before_filter :validate_filter_params, only: [:index]

  before_filter :validate_url_params, only: [:show]

  after_filter :set_root_key, :set_app_data_version, if: :private_api?

  around_filter :handle_notification, if: :import_api?

 # This should be the last arount filter , can be make available to public as needed
  around_filter :response_cache, only: [:index, :show], if: :private_api?

  after_filter :remove_session_data, :unset_current_languge

  SINGULAR_RESPONSE_FOR = %w(show create update).freeze
  COLLECTION_RESPONSE_FOR = %w(index search).freeze
  CURRENT_VERSION = 'private-v1'.freeze

  SLAVE_ACTIONS = %w(index).freeze

  NAMESPACED_CONTROLLER_REGEX = /pipe\/|channel\/v2\/|channel\/|bot\//
  BEARER_REGEX = /Bearer (.*)/.freeze
  RESPONSE_CACHE_TIMEOUT = 30.days.to_i

  CHANNEL_V2_PATHS = %w[update_multiple /api/channel/v2/agents /api/channel/v2/canned_responses /api/channel/v2/conversations].freeze

  def response_cache
    if response_cache_data.present?
      Rails.logger.info "API cache HIT | #{controller_name}/#{action_name} | Acc: #{current_account.id}"
      response.body = response_cache_data
      response.headers['Content-Type'] = "application/json; charset=utf-8" #assumption we are handling only json response
    else
      Rails.logger.info "API cache MISS | #{controller_name}/#{action_name} | Acc: #{current_account.id}"
      yield
      MemcacheKeys.cache(format(response_cache_key, account_id: current_account.id), response.body, RESPONSE_CACHE_TIMEOUT) if response_cache_key
    end
  end

  def response_cache_key
    @cache_key ||= self.class::RESPONSE_CACHE_KEYS[action_name] if defined? self.class::RESPONSE_CACHE_KEYS
  end

  def response_cache_data
    @cache_data ||= MemcacheKeys.get_from_cache(response_cache_key % { account_id: current_account.id }) if response_cache_key
  end

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
    head 204
  end

  def route_not_found
    path = env['PATH_INFO']
    allows = ActionDispatch::Routing::HTTP_METHODS.select do |verb|
      match = Rails.application.routes.recognize_path(path, method: verb)
      match[:action] != 'route_not_found'
    end.map(&:upcase)
    if allows.present? # route is present, but method is not allowed.
      render_405_error(allows)
    else # route not present.
      head 404
    end
  end

  def cname_params
    params[cname]
  end

  def app_authorization?
    # exposing private api(to allow get method only) for internal apps
    request.headers['X-App-Header'].present? && ( request.method == 'GET' || white_listed_for_app_auth? )
  end

  def white_listed_for_app_auth?
    ApiConstants::APP_AUTHORIZATION_WHITELIST[controller_path].include?(action_name.to_sym)
  end

  def app_current?
    Thread.current[:app_integration].present?
  end

  protected

    def requires_feature(*f) # Should be from cache. Need to revisit.
      features_list = feature_name.present? ? Account.current.enabled_features_list : Account.current.all_launched_features
      return if f.all? { |x| features_list.include?(x) }
      render_request_error(:require_feature, 403, feature: f.join(',').titleize)
    end

    def requires_any_feature(*features)
      features_list = feature_name.present? ? Account.current.enabled_features_list : Account.current.all_launched_features
      return if (features_list & features).present?

      render_request_error(:require_any_feature, 403, feature: features.join(',').titleize)
    end

    def render_partial_success(succeeded, failed, render_path=nil)
      @succeeded = succeeded
      @failed = failed
      (@failed || []).each do |item|
        item[:errors], item[:error_options] = format_custom_errors(item[:validation_errors], item[:validation_errors].respond_to?(:error_options)) if item[:validation_errors]
        item[:errors] = ErrorHelper.format_error(item[:errors], item[:error_options] || {})
      end
      log_error_response @failed
      render_path ? render(render_path, status: 202) : render('/partial_success', status: 202)
    end

    def portal_url
      main_portal? ? current_account.host : current_portal.portal_url
    end

  private

    def response_info
      CustomRequestStore.store[:extra_credits] = 0
    end

    def remove_ignore_params

    end

    def render_500(e)
      raise e if Rails.env.development? || Rails.env.test?
      notify_new_relic_agent(e, description: 'Error occured while processing api request')
      unless Rails.env.production?
        Rails.logger.error("API 500 error: #{e.message} \n #{e.backtrace.to_a.join("\n")}")
      end
      render_base_error(:internal_error, 500)
    end

    def duplicate_value_error(e)
      notify_new_relic_agent(e, description: 'Duplicate Record Error.')
      render_request_error(:duplicate_value, 409)
    end

    def range_error(e)
      # http://ruby-doc.org/core-2.1.0/RangeError.html
      # https://github.com/mislav/will_paginate/blob/master/lib/will_paginate/page_number.rb#L18
      # We are rescuing the exception without validating in order to avoid manipulations in every request to validate a rare scenario.
      if e.message.starts_with?('invalid offset') && params[:page].respond_to?(:to_i) && @per_page && ((params[:page].to_i - 1) * (@per_page + 1)) > ApiConstants::PAGE_MAX
        # raised by will_paginate gem
        render_errors([[:page, :max_limit_page]])
      else
        # unexpected exception
        notify_new_relic_agent(e, description: 'Invalid Offset Error.')
        render_base_error(:internal_error, 500)
      end
      Rails.logger.error("Invalid Offset Error: #{params.inspect} \n#{e.message}\n#{e.backtrace.join("\n")}")
    end

    def db_query_error(e)
      notify_new_relic_agent(e, description: 'Invalid/malformed query error occured while processing api request')
      Rails.logger.error("DB Query Invalid Error: #{params.inspect} \n#{e.message} \n#{e.backtrace.to_a.join("\n")}")
      render_base_error(:internal_error, 500)
    end

    def record_not_found(e)
      # Render 404 if domain is not present else 500.
      if e.is_a?(ShardNotFound)
        Rails.logger.error("API V2 request for invalid host. Host: #{request.host}")
        head 404
      elsif e.is_a?(DomainNotReady)
        render_base_error(:domain_not_ready, 404)
      else
        notify_new_relic_agent(e, description: 'ActiveRecord::RecordNotFound error occured while processing api request')
        Rails.logger.error("Record not found error. Domain: #{request.domain} \n params: #{params.inspect} \n#{e.message}\n#{e.backtrace.to_a.join("\n")}")
        render_base_error(:internal_error, 500)
      end
    end

    def activerecord_error_handler(e)
      err = ActiveRecord::Base.connection.safe_send(:translate_exception, e, e.message)
      err.instance_variable_set :@original_exception, nil
      case err.class.to_s
      when 'ActiveRecord::RecordNotUnique'
        duplicate_value_error(err)
      when 'ActiveRecord::StatementInvalid'
        db_query_error(err)
      when 'ActiveRecord::RecordNotFound'
        record_not_found(err)
      else
        render_500(err)
      end
    end

    def invalid_field_handler(exception) # called if extra fields are present in params.
      return if handle_invalid_multipart_form_data(exception.params) || handle_invalid_parseable_json(exception.params)
      Rails.logger.error("API Unpermitted Parameters. Params : #{params.inspect} Exception: #{exception.class}  Exception Message: #{exception.message}")
      inaccessible_fields = @all_fields ? @all_fields.flat_map(&:last) & exception.params : []
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

    def login_error_handler(e)
      if e.failed_login_count
        Rails.logger.debug "API V2 #{e.message}. Attempt: #{e.failed_login_count}"
        render_request_error :password_lockout, 403, max_count: UserSession.consecutive_failed_logins_limit
      else
        Rail.logger.debug "Exception: ConsecutiveFailedLoginError, Message: #{e.message}, Backtrace: #{e.backtrace}"
        render_base_error(:internal_error, 500)
      end
    end

    def ensure_proper_fd_domain # 404
      return true if Rails.env.development?
      unless ApiConstants::ALLOWED_DOMAIN == request.domain && current_account.full_domain != ApiConstants::DEMOSITE_URL # API V2 not permitted on Demosites
        Rails.logger.error "API V2 request for not allowed domain. Domain: #{request.domain}"
        head 404
      end
    end

    def ensure_proper_protocol
      return true if Rails.env.test? || Rails.env.development?
      render_request_error(:ssl_required, 403) unless request.ssl?
    end

    def render_request_error(code, status, params_hash = {})
      @error = RequestError.new(code, params_hash)
      log_error_response @error
      render '/request_error', status: status
    end

    def render_request_error_with_info(code, status, params_hash = {}, info = {})
      @error = RequestErrorWithInfo.new(code, params_hash, info)
      log_error_response @error
      render '/request_error_with_info', status: status
    end

    def render_base_error(code, status, params_hash = {})
      @error = BaseError.new(code, params_hash)
      log_error_response @error
      render '/base_error', status: status
    end

    def check_account_state
      if current_account.suspended?
        if private_api?
          render_request_error(:account_suspended, 402) if RESTRICTED_ACCESS_METHODS.include?(request.method_symbol)
        else
          render_request_error(:account_suspended, 403)
        end
      end
    end

    def set_cache_buster
      response.headers['Cache-Control'] = 'no-cache, no-store, max-age=0, must-revalidate'
      response.headers['Pragma'] = 'no-cache'
      response.headers['Expires'] = 'Wed, 13 Oct 2010 00:00:00 UTC'
    end

    def feature_name
      # Template method - Redefine if the controller needs requires_feature before_filter
    end

    def launch_party_name
      # Template method - Redefine if the controller needs requires_launch_party before_filter
    end

    def validate_content_type
      unless get_request? || request.delete? || content_type_not_required? || valid_content_type?
        render_request_error :invalid_content_type, 415, content_type: request.content_type
      end
    end

    def content_type_not_required?
      ApiConstants::NO_CONTENT_TYPE_REQUIRED.include?(action_name.to_sym)
    end

    def before_build_object
      # Template method to stop execution just before build_object
    end

    def before_load_object
      # Template method to stop execution just before load_object
    end

    def load_object(items = scoper)
      @item = items.find_by_id(params[:id])
      log_and_render_404 unless @item
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
      render_errors(@filter.errors, @filter.error_options) unless @filter.valid?
    end

    def validate_url_params
      # Template method - If embedding is present in show action, this can be used to validate
      # the imput sent using strong params and custom validations.
    end

    # will take scoper as one argument.
    def load_objects(items = scoper, paginate = true)
      @items_count = items.count if private_api?
      @items = paginate ? paginate_items(items) : items
    end

    # will take items as one argument and is_array (whether scoper is a AR or array as another argument.)
    def paginate_items(items)
      is_array = !items.respond_to?(:scoped) # check if it is array or AR
      options = paginate_options(is_array).symbolize_keys!
      offset = @per_page * (page - 1) unless is_array # assign offset unless scoper is array
      paginated_items = if options.keys.any?{ |x| ApiConstants::PAGINATION_ATTRIBUTES.exclude?(x) }
        # PRE-RAILS: Need to refactor the code, handle ar options in respective controllers if paginate_options is overridden
        is_array ? paginate_scoper(items, options) : paginate_scoper(items, options).offset(offset)
      else
        is_array ? items.paginate(options) : items.paginate(options).offset(offset) # rubocop:disable Gem/WillPaginate
      end

      # next page exists if scoper is array & next_page is not nil or
      # next page exists if scoper is AR & collection length > per_page
      next_page_exists = paginated_items.length > @per_page || is_array && paginated_items.next_page
      if next_page_exists
        add_link_header(page: (page + 1))
        @more_items = true
      else
        @more_items = false
      end
      paginated_items[0..(@per_page - 1)] # get paginated_collection of length 'per_page'
    end

    # Add link header if next page exists.
    def add_link_header(query_parameters)
      response.headers['Link'] = construct_link_header(query_parameters)
    end

    def add_total_entries(total_items)
      response.headers['X-Search-Results-Count'] = total_items.to_s
    end

    def add_etag_to_response_header(timestamp)
      response.headers['ETag'] = EtagGenerator.generate_etag(timestamp, self.class::CURRENT_VERSION)
      response.headers['Cache-Control'] = 'private'
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
    def render_201_with_location(template_name: "#{controller_path.gsub(NAMESPACED_CONTROLLER_REGEX, '')}/#{action_name}", location_url: "#{nscname}_url", item_id: @item.id)
      render template_name, location: safe_send(location_url, item_id), status: 201
    end

    def nscname # namespaced controller name
      controller_path.gsub(NAMESPACED_CONTROLLER_REGEX, '').tr('/', '_').singularize
    end

    def set_custom_errors(_item = @item)
      # This is used to manipulate the model errors to a format that is acceptable.
    end

    def render_custom_errors(item = @item, merge_item_error_options = false)
      errors, options = format_custom_errors(item, merge_item_error_options)
      render_errors(errors, options || {})
    end

    def format_custom_errors(item = @item, merge_item_error_options = false)
      options = set_custom_errors(item) # this will set @error_options if necessary.

      # Remove raw errors from model if remove option specified
      Array.wrap(options.delete(:remove)).each { |field| item.errors[field].clear } if options

      # Rename keys in error_options if error_options_mappings exists
      if merge_item_error_options && item.error_options
        ErrorHelper.rename_keys(error_options_mappings, item.error_options)
        (options ||= {}).merge!(item.error_options)
      end
      [item.errors, options]
    end

    # Error options field mappings to rename the keys Say, agent in ticket error will be replaced with responder_id
    def error_options_mappings
      {}
    end

    def render_errors(errors, meta = {})
      if errors.present?
        @errors = ErrorHelper.format_error(errors, meta)
        log_error_response @errors
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
        Rails.logger.error "API 403 Error: customer  = #{api_current_user.customer?}"
        render_request_error :access_denied, 403
      else
        render_request_error :invalid_credentials, 401
      end
    end

    def jwt_auth_request
      return unless CustomRequestStore.read(:private_api_request)
      auth_token = request.headers['Authorization']
      auth_token = auth_token.match(BEARER_REGEX) unless auth_token.nil?
      auth_token = auth_token[1].strip if !auth_token.nil? && auth_token.length > 1

      jwt_header = auth_token.split('.')[0] if !auth_token.nil? && auth_token.length > 1
      kid = JSON.parse(Base64.decode64(jwt_header))['kid'] rescue nil if jwt_header

      if kid == ::Iam::IAM_CONFIG['kid']
        key = OpenSSL::PKey::RSA.new(File.read('config/cert/iam_public.pem'))
        begin
          payload, _headers = JWT.decode auth_token, key, true, { algorithm: 'RS256' }
          @current_user = Account.current.users.find_by_id(payload['user_id'])
        rescue Exception => e
          render_request_error :invalid_credentials, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
          Rails.logger.error "Exception while authenticating user using JWT token, message: #{e.message}"
        end
      end
    end

    def api_current_user
      @current_user || jwt_auth_request # Authenticating using JWT token from IAM service for private APIs

      return @current_user if defined?(@current_user)

      # Private API is supposed to work with session based authentication
      if CustomRequestStore.read(:private_api_request) || (get_request? && !request.authorization)
        session_auth
      elsif CustomRequestStore.read(:channel_api_request)
        CHANNEL_V2_PATHS.any? { |path| request.path.include?(path) } ? channel_v2_jwt_auth : api_key_auth
      else
        if current_account.launched?(:api_jwt_auth) && request.env['HTTP_AUTHORIZATION'] && request.env['HTTP_AUTHORIZATION'][/^Token (.*)/]
          ApiAuthLogger.log "FRESHID API version=V2, auth_type=JWT_TOKEN, a=#{current_account.id}"
          # authenticate using JWT token
          authenticate_with_http_token do |token|
            @current_user = FdJWTAuth.new(token).decode_jwt_token
          end
        else
          basic_auth
        end
      end

      # should be defined in case of invalid credentials as api_current_user gets called repeatedly.
      @current_user ||= nil
    end

    def session_auth
      if current_user_session # fall back to old session based auth
        @current_user = session.key?(:assumed_user) ? (current_account.users.find session[:assumed_user]) : current_user_session.record
        stale_record = current_user_session.stale_record
        if @current_user
          @current_user.update_failed_login_count(true) if @current_user.failed_login_count != 0 && login_via_email?
          # to avoid query to check for password expiry. We know for sure that passowrd won't be expired if record is not nil
          @current_user.password_expired = false
        elsif stale_record && stale_record.password_expired
          @current_user = stale_record # stale_record would be set in case of password expiry. record would be nil.
        end
      end
    end

    def basic_auth
      # authenticate using auth headers
      authenticate_with_http_basic do |username, password| # authenticate_with_http_basic - AuthLogic method
        # string check for @ is used to avoid a query.
        @current_user = email_given?(username) ? AuthHelper.get_email_user(username, password, request.ip) : AuthHelper.get_token_user(username)
      end
    end

    def api_key_auth
      authenticate_with_http_basic do |username, password|
        @current_user = AuthHelper.get_token_user(username)
      end
    end

    def channel_v2_jwt_auth
      auth = request.headers['Authorization']
      auth = auth.match(BEARER_REGEX) unless auth.nil?
      auth = auth[1].strip if !auth.nil? && auth.length > 1
      begin
        payload = JWT.decode auth, CHANNEL_V2_API_CONFIG['jwt_secret']
        current_user_id = payload.first['current_user_id'] if payload.first.is_a?(Hash)
      rescue Exception => e
        render_request_error :invalid_credentials, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
      end
      @current_user = current_user_id.present? ? Account.current.technicians.find_by_id(current_user_id) :
                                                 Account.current.account_managers.first
    end

    def email_given?(username)
      return @email_given if defined?(@email_given)
      @email_given ||= username.try(:include?, '@')
    end

    def login_via_email?
      email_given?(params[:k])
    end

    def qualify_for_day_pass? # this method is redefined because of api_current_user
      api_current_user && api_current_user.occasional_agent? && !current_account.subscription.trial? && !is_assumed_user?
    end

    def check_privilege # this method is redefined because of api_current_user
      return true if app_current?
      if api_current_user.nil? || api_current_user.customer? || !allowed_to_access?
        access_denied
        return false
      elsif verify_password_expired?
        render_request_error :password_expired, 403
        return false
      end
      true
    end

    def verify_password_expired?
      return @pwd_expired if defined?(@pwd_expired)
      @pwd_expired ||= (login_via_email? && (api_current_user.password_expired || password_expired_for_user?))
    end

    def password_expired_for_user?
      # password_expired attribute would be nil if check was not done previously.
      # This check is to avoid queries getting fired in password_expired? method.
      api_current_user.password_expired.nil? && api_current_user.password_expired?
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

    def set_current_account
      if Account.current # This would be present because of fd_api_throttler.
        @current_account = Account.current # setting instance variables
      else
        current_account.make_current
      end
      set_current_portal

      set_account_meta_cookies
      User.current = api_current_user
      Thread.current[:message_uuid] = request.try(:uuid).to_a
      if private_api?
        log_session_details(:set_current_account) if Account.current.session_logs_enabled?
      else
        log_locale
      end
    rescue ActiveRecord::RecordNotFound, ShardNotFound
      Rails.logger.error("API V2 request for invalid account. Host: #{request.host}")
      head 404
    rescue ActiveSupport::MessageVerifier::InvalidSignature # Authlogic throw this error if signed_cookie is tampered.
      render_request_error :credentials_required, 401
    end

    def set_current_portal
      @current_portal ||= Portal.fetch_by_url(request_host) || @current_account.main_portal_from_cache
      @current_portal.make_current
    end

    def get_request?
      @get_request ||= request.get?
    end

    def can_send_user? # if user_id or email of a user, is included in params, the api_current_user should have ability to assume that user.
      user_id = params[cname][:user_id] || params[cname][:agent_id]
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
      # PRE-RAILS: will_paginate 3.1.7 won't support offset params
      @per_page = per_page # user given/defualt page number
      options[:per_page] = is_array ? @per_page : @per_page + 1 # + 1 to find next link unless scoper is array
      options[:page] = page
      options[:total_entries] = options[:page] * options[:per_page] unless is_array # To prevent paginate from firing count query unless scoper is array
      options
    end

    def page
      (params[:page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:page]).to_i
    end

    def per_page
      (params[:per_page] || ApiConstants::DEFAULT_PAGINATE_OPTIONS[:per_page]).to_i
    end

    def get_fields(constant_name, item = @item, owned_by_field = :user_id) # retrieves fields that strong params allows by privilege.
      constant = constant_name.constantize
      get_fields_from_constant(constant, item, owned_by_field)
    end

    def get_fields_from_constant(constant, item, owned_by_field)
      # all_fields is used to differentiate between junk fields and inaccessible_fields in invalid_field_handler.
      # all_fields should not be modified as it a reference to the constant and not a separate object.
      # item is sent to privilege to accomodate owned_by privileges.
      @all_fields = constant
      fields = constant[:all] || []
      owned_by_permissions = constant.except(:all).keys & ApiConstants::PRIVILEGES_WITH_OWNEDBY
      permissions = constant.except(:all, *owned_by_permissions).keys
      permissions.each { |key| fields += constant[key] if privilege?(key) }
      owned_by_permissions.each { |key| fields += constant[key] if privilege_or_owns_object?(key, item, owned_by_field) }
      fields
    end

    def privilege_or_owns_object?(key, item, owned_by_field)
      # this method assumes that,
      # when load_object is not called then the action is a create action,
      # other actions using owned_by permissions is, presently a non-existent and in future also, a rare scenario
      # when user_id parameter is not present in the request, then api_current_user.id will be assigned eventually to the record.
      # # Should have either the privilege or owns the object
      privilege?(key) || object_of_current_user?(item, owned_by_field)
    end

    def object_of_current_user?(item, owned_by_field)
      owner_id_same_as_current_user?(owned_by_field) && (item.nil? || api_current_user.owns_object?(item))
    end

    def owner_id_same_as_current_user?(owned_by_field)
      params[cname].try(:[], owned_by_field).nil? || params[cname][owned_by_field] == api_current_user.id
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
      @string_request_params ||= (request.content_type.try(:include?, 'multipart/form-data') || allowed_http_method?)
      @string_request_params
    end

    def allowed_http_method?
      get_request? || request.delete?
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
      options_hash = { uri: request.original_url, custom_params: custom_params.merge(method: request.method, params: params, x_request_id: request.uuid) }
      NewRelic::Agent.notice_error(exception, options_hash)
    end

    def increment_api_credit_by(value)
      CustomRequestStore.store[:extra_credits] += value
    end

    def log_error_response(errors)
      # to get printed in the hash format, we have this manipulation.
      hash_format = errors.is_a?(Array) ? errors.map(&:instance_values) : errors.instance_values
      Rails.logger.debug "API V2 Error Response : #{hash_format.inspect}"
    end

    def log_and_render_404
      Rails.logger.debug "API V2 Item not present. Id: #{params[:id]}, method: #{params[:action]}, controller: #{params[:controller]}"
      head 404
    end

    def render_405_error(allowed_methods)
      methods = allowed_methods.join(', ')
      render_base_error(:method_not_allowed, 405, methods: methods, fired_method: request.method)
      response.headers['Allow'] = methods
    end

    def check_day_pass_usage_with_user_time_zone
      user_zone = TimeZone.find_time_zone
      Time.use_zone(user_zone) { check_day_pass_usage }
    end

    def use_time_zone
      Time.use_zone(TimeZone.set_time_zone) do
        yield
      end
    end

    def run_on_slave
      Rails.logger.debug "---- Running #{self.class.name}##{action_name} on slave db----"
      Sharding.run_on_slave do
        yield
      end
    end

    def csrf_check_reqd?
      return false unless CustomRequestStore.read(:private_api_request)
      request.cookies['_helpkit_session'] && !get_request?
    end

    def handle_unverified_request
      log_session_details(:handle_unverified_request) if Account.current && Account.current.session_logs_enabled?
      render_request_error :invalid_credentials, 401
      # TODO-EMBERAPI Need to decide what exactly to send back
    end

    def log_session_details(parent)
      Rails.logger.info "Session details logging :: #{parent} :: #{request.headers['X-CSRF-Token']} :: #{session.inspect}"
    end

    def set_root_key
      return unless params[:version] == 'private' && response.api_root_key.blank?
      response.api_root_key = case action_name
                              when *self.class::SINGULAR_RESPONSE_FOR
                                api_root_key.singularize
                              when *self.class::COLLECTION_RESPONSE_FOR
                                api_root_key.pluralize
                              else
                                :data
                              end
    end

    def api_root_key
      @api_root_key ||=
        defined?(self.class::ROOT_KEY) ? self.class::ROOT_KEY.to_s : controller_name.gsub('api_', '')
    end

    def request_host
      @request_host ||= request.host
    end

    def private_api?
      @private_api ||= params[:version].to_sym == :private
    end

    def public_api?
      @public_api ||= params[:version].to_sym == :v2
    end

    def import_api?
      params[:import_id].present?
    end

    def run_on_db
      db_type = current_account.master_queries? ? :run_on_master : :run_on_slave
      Sharding.safe_send(db_type) do
        yield
      end
    end

    def on_slave?
      get_request? && self.class::SLAVE_ACTIONS.include?(action_name)
    end

    def custom_field_error_mappings
      @custom_field_error_mapping ||= Hash[@name_mapping.map{|k,v| [k, "custom_fields.#{v}"]}] if @name_mapping.present?
    end

    def set_default_locale
      I18n.locale = I18n.default_locale
    end

    def set_current_ip
      Thread.current[:current_ip] = request.env['CLIENT_IP']
    rescue Exception => e
      Rails.logger.debug "Error getting currernt IP : #{e.message}"
    end

    def set_locale
      begin
        I18n.locale = (api_current_user.try(:language) || current_portal.try(:language) || I18n.default_locale)
      rescue StandardError => exception
        Rails.logger.debug "Exception on set locale :: #{exception.message}"
        I18n.default_locale
      end
      # log_locale
    end

    def authenticate_jwt_request
      jwt_auth = AppJWTAuth.new(request.headers['X-App-Header'])
      jwt_auth.decode_jwt_token
      if jwt_auth.verify_auth? && valid_app_payload?(jwt_auth.payload)
        assign_current_app(jwt_auth.payload[:app_name])
      else
        render_request_error :invalid_credentials, Rack::Utils::SYMBOL_TO_STATUS_CODE[:unauthorized]
      end
    end

    def valid_app_payload?(payload)
      case payload[:app_name]
      when 'freshconnect'
        payload[:product_account_id].present? && current_account.freshconnect_account.try(:product_account_id) == payload[:product_account_id]
      else
        true
      end
    end

    def assign_current_app(app_name)
      Thread.current[:app_integration] = app_name
    end

    def handle_notification
      disable_notification
      yield
    ensure
      enable_notification
    end

    def log_locale
      Rails.logger.info "Locale:: #{I18n.locale}, User:: #{User.current.try(:id)}, User lang:: #{User.current.try(:language)}, Account lang:: #{Account.current.language}"
    end

    def log_csrf
      start_token = session[:_csrf_token] if session
      yield
      end_token = session[:_csrf_token] if session
      Rails.logger.info "CSRF observed :: changed :: true :: #{start_token} :: #{end_token} :: Tab :: #{request.env['HTTP_X_CLIENT_INSTANCE_ID']}" if start_token != end_token
      Rails.logger.info "Tab ID :: #{request.env['HTTP_X_CLIENT_INSTANCE_ID']} "
    end

    def remove_session_data
      session[:helpdesk_history] = nil if session && session[:helpdesk_history]
    end

    def set_service_worker
      if current_account.service_worker_enabled?
        cookies[:service_worker] = true
      else
        cookies.delete 'service_worker'
      end
    end

    def supress_logs(temporary_level = Logger::ERROR)
      if current_account.launched?(:disable_supress_logs)
        yield
      else
        begin
          old_level = ActiveRecord::Base.logger.level
          ActiveRecord::Base.logger.level = temporary_level
          yield
        ensure
          ActiveRecord::Base.logger.level = old_level
        end
      end
    end
end
