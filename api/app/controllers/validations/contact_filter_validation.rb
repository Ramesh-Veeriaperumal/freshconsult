class ContactFilterValidation < ApiValidation
  attr_accessor :state, :phone, :mobile, :email, :company_id, :conditions

  validates :state, custom_inclusion: { in: ContactConstants::CONTACT_FILTER }, allow_nil: true
  validates :email, format: { with: AccountConstants::EMAIL_REGEX, message: 'not_a_valid_email' }, allow_nil: true
  validate :check_company, if: -> { company_id }
  
  def initialize(request_params)
    @conditions = request_params.keys & ContactConstants::INDEX_CONTACT_FIELDS
    super(request_params)
  end

  def check_company
    company = Account.current.companies_from_cache.find { |c| c.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless company
  end

end
