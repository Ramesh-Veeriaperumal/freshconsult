class TicketFilterValidation < ApiValidation
  attr_accessor :filter, :company_id, :requester_id, :created_since, :updated_since,
                :order_by, :order_type, :conditions

  validate :check_requester, if: -> { requester_id }
  validate :check_company, if: -> { company_id }
  validates :filter, custom_inclusion: { in: ApiTicketConstants::TICKET_FILTER }, allow_nil: true
  validates :created_since, :updated_since, date_time: { allow_nil: true }
  validates :order_by, custom_inclusion: { in: ApiTicketConstants::TICKET_ORDER_BY }, allow_nil: true
  validates :order_type, custom_inclusion: { in: ApiTicketConstants::TICKET_ORDER_TYPE }, allow_nil: true

  def initialize(request_params)
    @conditions = request_params.keys - [:filter] + [request_params[:filter]].compact
    super(request_params)
  end

  def check_requester
    requester = Account.current.all_users.where(id: @requester_id).first
    errors.add(:requester_id, "can't be blank") unless requester
  end

  def check_company
    company = Account.current.companies_from_cache.detect { |c| c.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless company
  end
end
