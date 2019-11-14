class TicketFilterValidation < FilterValidation
  include TicketFilterConstants
  attr_accessor :filter, :company_id, :requester_id, :email, :updated_since,
                :order_by, :conditions, :requester, :status, :cf, :include,
                :include_array, :exclude, :exclude_array, :query_hash, :only, :type

  validates :page, custom_numericality: {
    only_integer: true, greater_than: 0, ignore_string: :allow_string_param,
    less_than_or_equal_to: ApiTicketConstants::MAX_PAGE_LIMIT,
    custom_message: :tickets_page_invalid, message_options: { max_value: ApiTicketConstants::MAX_PAGE_LIMIT }
  }
  validates :company_id, :requester_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validate :verify_requester, if: -> { errors[:requester_id].blank? && (requester_id || email) }
  validate :verify_company, if: -> { errors[:company_id].blank? && company_id }
  validates :email, data_type: { rules: String }
  validates :filter, custom_inclusion: { in: ApiTicketConstants::FILTER }, if: -> { !private_api? }
  validates :updated_since, date_time: true
  validates :order_by, custom_inclusion: { in: proc { |x| x.sort_field_options } }
  validates :status, array: { custom_inclusion: { in: proc { |x| x.account_statuses }, ignore_string: :allow_string_param, detect_type: true } }
  validate :fsm_appointment_time_filter_validation, if: -> { Account.current.field_service_management_enabled? && @query_hash.present? }
  validate :verify_cf_data_type, if: -> { cf.present? }
  validates :include, data_type: { rules: String }
  validates :type, custom_inclusion: { in: proc { |x| x.account_ticket_types } }
  validate :query_hash_or_filter_presence
  # query_hash should either be an empty string or a hash.
  # This is for 'any_time' created_at filter for which default_filter should not be applied
  # TODO: This should be handled more elegantly
  validates :query_hash, data_type: { rules: String, allow_nil: false }, unless: -> { query_hash.is_a?(Hash) }
  validates :query_hash, data_type: { rules: Hash, allow_nil: false }, if: -> { errors[:filter].blank? && !query_hash_empty_string? }
  validate :validate_include, if: -> { errors[:include].blank? && include }
  validate :validate_exclude, if: -> { private_api? && errors[:exclude].blank? && exclude }
  validate :validate_filter_param, if: -> { errors[:filter].blank? && filter.present? && private_api? }
  validate :validate_query_hash, if: -> { errors.blank? && query_hash.present? }
  validates :ids, data_type: { rules: Array, allow_nil: false },
                  array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param } },
                  custom_length: { maximum: ApiConstants::MAX_ITEMS_FOR_BULK_ACTION, message_options: { element_type: :values } }
  validates :only, custom_inclusion: { in: ApiTicketConstants::ALLOWED_ONLY_PARAMS }

  def initialize(request_params, item = nil, allow_string_param = true)
    @email = request_params.delete('email') if request_params.key?('email') # deleting email and replacing it with requester_id
    if @email
      @requester = Account.current.user_emails.user_for_email(@email)
      request_params['requester_id'] = @requester.try(:id) if @requester
    end
    @conditions = (request_params.keys & ApiTicketConstants::INDEX_FILTER_FIELDS)
    filter_name = fetch_filter(request_params)
    @conditions = @conditions - ['filter'] + [filter_name].compact
    self.skip_hash_params_set = true
    request_params[:ids] = request_params[:ids].split(',') if request_params.key?(:ids)
    super(request_params, item, allow_string_param)
    @status = status.to_s.split(',') if request_params.key?('status')

    @version = request_params[:version]
  end

  def verify_requester
    # This validation will not query again if @email is set
    requester = @email ? @requester : Account.current.all_users.where(id: @requester_id).first
    errors[find_attribute] << :"can't be blank" unless requester
  end

  def verify_company
    company = Account.current.companies.find_by_id(@company_id)
    errors[:company_id] << :"can't be blank" unless company
  end

  def query_hash_empty_string?
    # query_hash should be 'hash' validated only if it is not an empty string
    query_hash == ''
  end

  def find_attribute
    @email ? :email : :requester_id
  end

  def fsm_appointment_time_filter_validation
    if @query_hash.is_a?(Hash)
      query_key = get_query_key
      query_key.each do |query|
        check_dates_and_range(query) unless DATE_TIME_FILTER_DEFAULT_OPTIONS.include?(@query_hash[query]['value'])
      end
    end
  end

  def get_query_key
    fsm_conditions = []
    @query_hash.keys.each do |query|
      if FSM_DATE_TIME_FIELDS.include?(@query_hash[query]['condition'])
        fsm_conditions << query
      end
    end
    fsm_conditions
  end

  def check_dates_and_range(query)
    start_time = @query_hash[query]['value'][:from].try(:to_datetime)
    end_time = @query_hash[query]['value'][:to].try(:to_datetime)
    if start_time && end_time
      given_date_range = (end_time - start_time).to_f
      errors[:"query_hash[#{query}]"] << :invalid_date_time_range if given_date_range < 0
    end
  rescue Exception => e
    errors[:"query_hash[#{query}]"] << :query_format_invalid
  end

  def verify_cf_data_type
    cf.collect do |x|
      if instance_values.key?(x) && !instance_values[x].is_a?(String)
        errors[x] << :data_type_mismatch
        (self.error_options ||= {}).merge!(x.to_sym => { data_type: 'String' })
      end
    end
  end

  # if there are any filters(such as requester_id or company_id) at all in query params, fetch filter query value. else return default filter.
  def fetch_filter(request_params)
    @conditions.present? ? request_params[:filter] : 'default'
  end

  def account_statuses
    @statuses = Helpdesk::TicketStatus.status_objects_from_cache(Account.current).map(&:status_id)
  end

  def validate_include
    @include_array = include.split(',').map!(&:strip)
    feature_based_include_array = @include_array & TicketFilterConstants::FEATURES_KEYS_BY_SIDE_LOAD_KEY.keys
    if @include_array.blank? || (@include_array - allowed_side_load_params).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: allowed_side_load_params.join(', ') })
    elsif feature_based_include_array.present? && private_api?
      accessible_side_loadings = TicketsFilter.accessible_filters(feature_based_include_array, TicketFilterConstants::FEATURES_KEYS_BY_SIDE_LOAD_KEY)
      unauthorised_side_loadings = feature_based_include_array - accessible_side_loadings
      if unauthorised_side_loadings.present?
        errors[:include] << :require_feature
        (self.error_options ||= {}).merge!(include: { feature: TicketFilterConstants::FEATURES_NAMES_BY_SIDE_LOAD_KEY[unauthorised_side_loadings.first] })
      end
    end
  end

  def validate_exclude
    @exclude_array = exclude.split(',').map!(&:strip)
    if @exclude_array.blank? || (@exclude_array - ApiTicketConstants::EXCLUDABLE_FIELDS).present?
      errors[:exclude] << :not_included
      (self.error_options ||= {}).merge!(exclude: { list: ApiTicketConstants::EXCLUDABLE_FIELDS.join(', ') })
    end
  end

  def allowed_side_load_params
    private_api? ? ApiTicketConstants::SIDE_LOADING : (ApiTicketConstants::SIDE_LOADING - ['survey'])
  end

  def query_hash_or_filter_presence
    errors[:filter] << :only_query_hash_or_filter if filter.present? && query_hash.present?
  end

  def validate_filter_param
    if filter.to_i.to_s == filter # Filter ID
      if filter.to_i <= 0
        errors[:filter] << :datatype_mismatch
        (self.error_options ||= {}).merge!(filter: { expected_data_type: 'Positive Integer' })
      end
    elsif !filter_exist?(filter)# Filter name
      errors[:filter] << :not_included
      (self.error_options ||= {}).merge!(filter: { list: TicketFilterConstants::FILTER.join(', ') })
    elsif !TicketsFilter.accessible_filter?(filter)
      errors[:filter] << :require_feature
      error_options.merge!(filter:
        { feature: TicketsFilter::FEATURES_NAMES_BY_FILTER_KEY[filter], code: :access_denied })
    end
  end

  def filter_exist?(filter)
    !filter.eql?('ongoing_collab') ? TicketFilterConstants::FILTER.include?(filter) : (Account.current.collaboration_enabled? && !Account.current.freshconnect_enabled?)
  end

  def validate_query_hash
    query_hash.each do |key, query|
      query_hash_validator = ::QueryHashValidation.new(query)
      next if query_hash_validator.valid?
      message = ErrorHelper.format_error(query_hash_validator.errors, query_hash_validator.error_options)
      messages = message.is_a?(Array) ? message : [message]
      errors[:"query_hash[#{key}]"] = messages.map { |m| "#{m.field}: #{m.message}" }.join(' & ')
    end
  end

  def sort_field_options
    TicketsFilter.api_sort_fields_options.map(&:first).map(&:to_s)
  end

  def account_ticket_types
    Account.current.ticket_types_from_cache.collect(&:value)
  end

  private

    def private_api?
      @version == 'private'
    end
end
