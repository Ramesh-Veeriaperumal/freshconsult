class TicketFilterValidation < ApiValidation
  attr_accessor :filter, :company_id, :requester_id, :created_since, :updated_since,
                :order_by, :order_type, :account, :value

  validate :check_requester, if: -> { requester_id }
  validate :check_company, if: -> { company_id }
  validates :filter, included: { in: ApiConstants::TICKET_FILTER }, allow_nil: true
  validates :created_since, :updated_since, date_time: { allow_nil: true }
  validates :order_by, included: { in: ApiConstants::TICKET_ORDER_BY }, allow_nil: true
  validates :order_type, included: { in: ApiConstants::TICKET_ORDER_TYPE }, allow_nil: true

  def initialize(request_params, account)
    @value = request_params.keys - [:filter] + [request_params[:filter]].compact
    @account = account
    super(request_params)
  end

  def check_requester
    requester = @account.all_users.where(id: @requester_id).first
    errors.add(:requester_id, "can't be blank") unless requester
  end

  def check_company
    company = @account.companies_from_cache.find { |c| c.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless company
  end
end
