class ContactFilterValidation < ApiValidation
  attr_accessor :state, :phone, :mobile, :email, :company_id, :conditions

  validates :state, custom_inclusion: { in: ContactConstants::STATES }, allow_nil: true
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, allow_nil: true
  validates :company_id, numericality: true, allow_nil: true
  validate :check_company, if: -> { company_id }

  def initialize(request_params)
    request_params['state'] = 'all' if request_params['state'].nil?
    @conditions = (request_params.keys & ContactConstants::INDEX_FIELDS) - ['state'] + [request_params['state']].compact
    super(request_params)
  end

  def check_company
    company = Account.current.companies_from_cache.find { |x| x.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless company
  end
end
