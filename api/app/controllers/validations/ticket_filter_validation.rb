class TicketFilterValidation < ApiValidation
  attr_accessor :filter, :company_id, :requester_id, :email, :updated_since,
                :order_by, :order_type, :conditions, :requester

  validates :company_id, :requester_id, custom_numericality: { allow_nil: true, only_integer: true, ignore_string: :allow_string_param, message: 'positive_number' }
  validate :check_requester, if: -> { errors[:requester_id].blank? && (requester_id || email) }
  validate :check_company, if: -> { errors[:company_id].blank? && company_id }
  validates :filter, custom_inclusion: { in: ApiTicketConstants::FILTER }, allow_nil: true
  validates :updated_since, date_time: { allow_nil: true }
  validates :order_by, custom_inclusion: { in: ApiTicketConstants::ORDER_BY }, allow_nil: true
  validates :order_type, custom_inclusion: { in: ApiTicketConstants::ORDER_TYPE }, allow_nil: true

  def initialize(request_params, item, allow_string_param)
    @email = request_params.delete('email') # deleting email and replacing it with requester_id
    if @email
      @requester = Account.current.user_emails.user_for_email(@email)
      request_params['requester_id'] = @requester.try(:id)
    end
    @conditions = (request_params.keys & ApiTicketConstants::INDEX_FIELDS)
    filter_name = request_params.fetch('filter', 'default')
    @conditions = @conditions - ['filter'] + [filter_name].compact
    super(request_params, item, allow_string_param)
  end

  def check_requester
    # This validation will not query again if @email is set
    requester = @email ? @requester : Account.current.all_users.where(id: @requester_id).first
    errors.add(:requester_id, "can't be blank") unless requester
  end

  def check_company
    company = Account.current.companies_from_cache.detect { |c| c.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless company
  end
end
