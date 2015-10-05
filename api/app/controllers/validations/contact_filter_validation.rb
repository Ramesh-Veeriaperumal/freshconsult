class ContactFilterValidation < ApiValidation
  attr_accessor :state, :phone, :mobile, :email, :company_id, :conditions

  validates :state, custom_inclusion: { in: ContactConstants::STATES }, allow_nil: true
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, allow_nil: true
  validates :company_id, custom_numericality: { allow_nil: true, only_integer: true, ignore_string: :string_param, messge: 'positive_number' }
  validate :check_company, if: -> { company_id && errors[:company_id].blank? }

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
