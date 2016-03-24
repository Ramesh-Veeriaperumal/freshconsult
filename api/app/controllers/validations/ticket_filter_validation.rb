class TicketFilterValidation < FilterValidation
  attr_accessor :filter, :company_id, :requester_id, :email, :updated_since,
                :order_by, :order_type, :conditions, :requester, :status, :cf

  validates :company_id, :requester_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param, greater_than: 0 }
  validate :verify_requester, if: -> { errors[:requester_id].blank? && (requester_id || email) }
  validate :verify_company, if: -> { errors[:company_id].blank? && company_id }
  validates :email, data_type: { rules: String, allow_unset: true }
  validates :filter, custom_inclusion: { in: ApiTicketConstants::FILTER, allow_unset: true }
  validates :updated_since, date_time: { allow_unset: true }
  validates :order_by, custom_inclusion: { in: ApiTicketConstants::ORDER_BY, allow_unset: true }
  validates :order_type, custom_inclusion: { in: ApiTicketConstants::ORDER_TYPE, allow_unset: true }
  validates :status, array: { custom_inclusion: { in: proc { |x| x.account_statuses }, ignore_string: :allow_string_param, detect_type: true } }
  validate :verify_cf_data_type, if: -> { cf.present? }

  def initialize(request_params, item = nil, allow_string_param = true)
    @email = request_params.delete('email') if request_params.key?('email') # deleting email and replacing it with requester_id
    if @email
      @requester = Account.current.user_emails.user_for_email(@email)
      request_params['requester_id'] = @requester.try(:id) if @requester
    end
    @conditions = (request_params.keys & ApiTicketConstants::INDEX_FILTER_FIELDS)
    filter_name = fetch_filter(request_params)
    @conditions = @conditions - ['filter'] + [filter_name].compact
    super(request_params, item, allow_string_param)
    @status = status.to_s.split(",") if request_params.key?("status")
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
      if instance_values.key?(x) and !instance_values[x].is_a?(String)
        errors[x] << :data_type_mismatch
        (self.error_options ||= {}).merge!(x.to_sym => { data_type: "String" })
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
end
