
class ContactFilterValidation < FilterValidation
  attr_accessor :state, :phone, :mobile, :email, :company_id, :updated_since, :conditions

  validates :state, custom_inclusion: { in: ContactConstants::STATES }, allow_nil: true
  validates :email, format: { with: ApiConstants::EMAIL_VALIDATOR, message: 'not_a_valid_email' }, allow_nil: true
  validates :company_id, custom_numericality: { allow_nil: true, only_integer: true, ignore_string: :allow_string_param, message: :positive_number }
  validate :check_company, if: -> { company_id && errors[:company_id].blank? }
  validates :updated_since, date_time: { allow_nil: true }

  def initialize(request_params, item, allow_string_param = true)
    request_params['state'] = 'all' if request_params['state'].nil?
    @conditions = (request_params.keys & ContactConstants::INDEX_FIELDS) - ['state'] + [request_params['state']].compact
    super(request_params, item, allow_string_param)
  end

  def check_company
    company = Account.current.companies_from_cache.find { |x| x.id == @company_id.to_i }
    errors[:company_id] << :blank unless company
  end
end
