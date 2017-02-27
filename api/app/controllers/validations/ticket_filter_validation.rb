class TicketFilterValidation < FilterValidation
  attr_accessor :filter, :company_id, :requester_id, :email, :updated_since,
                :order_by, :order_type, :conditions, :requester, :status, :cf, :include, 
                :include_array, :query_hash

  validates :company_id, :requester_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validate :verify_requester, if: -> { errors[:requester_id].blank? && (requester_id || email) }
  validate :verify_company, if: -> { errors[:company_id].blank? && company_id }
  validates :email, data_type: { rules: String }
  validates :filter, custom_inclusion: { in: ApiTicketConstants::FILTER }, if: -> { !private_API? }
  # Unless add_watcher feature is enabled, a user cannot be allowed to get tickets that he/she is "watching"
  validate :watcher_filter, if: -> { filter }
  validates :updated_since, date_time: true
  validates :order_by, custom_inclusion: { in: proc { |x| x.sort_field_options } }
  validates :order_type, custom_inclusion: { in: ApiTicketConstants::ORDER_TYPE }
  validates :status, array: { custom_inclusion: { in: proc { |x| x.account_statuses }, ignore_string: :allow_string_param, detect_type: true } }
  validate :verify_cf_data_type, if: -> { cf.present? }
  validates :include, data_type: { rules: String }
  validate :query_hash_or_filter_presence
  validates :query_hash, data_type: { rules: Hash, allow_nil: false }, if: -> { errors[:filter].blank? }
  validate :validate_include, if: -> { errors[:include].blank? && include }
  validate :validate_filter_param, if: -> { errors[:filter].blank? && filter.present? && private_API? }
  validate :validate_query_hash, if: -> { errors.blank? && query_hash.present? }
  validates :ids, data_type: { rules: Array, allow_nil: false }, 
            array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: false, ignore_string: :allow_string_param} },
            custom_length: { maximum: ApiConstants::MAX_ITEMS_FOR_BULK_ACTION, message_options: { element_type: :values } }

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

  def find_attribute
    @email ? :email : :requester_id
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
    if @include_array.blank? || (@include_array - ApiTicketConstants::SIDE_LOADING).present?
      errors[:include] << :not_included
      (self.error_options ||= {}).merge!(include: { list: ApiTicketConstants::SIDE_LOADING.join(', ') })
    elsif @include_array.include?('survey') && !Account.current.new_survey_enabled?
      errors[:include] << :require_feature
      (self.error_options ||= {}).merge!(include: { feature: 'Custom survey' })
    end
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
    elsif !TicketFilterConstants::FILTER.include?(filter) # Filter name
      errors[:filter] << :not_included
      (self.error_options ||= {}).merge!(filter: { list: TicketFilterConstants::FILTER.join(', ') })
    end
  end

  def validate_query_hash
    query_hash_errors = []
    query_hash.each do |key, query|
      query_hash_validator = ::QueryHashValidation.new(query)
      query_hash_errors << query_hash_validator.errors.full_messages unless query_hash_validator.valid?
    end
    if query_hash_errors.present?
      errors[:query_hash] << :"invalid_query_conditions"
    end
  end

  def watcher_filter
    if @filter == 'watching' && !Account.current.add_watcher_enabled?
      errors[:filter] << :require_feature
      error_options.merge!(filter: { feature: 'Add Watcher', code: :access_denied })
    end
  end

  def sort_field_options
    TicketsFilter::api_sort_fields_options.map(&:first).map(&:to_s) - ['priority']
  end

  private

    def private_API?
      @version == 'private'
    end
end
