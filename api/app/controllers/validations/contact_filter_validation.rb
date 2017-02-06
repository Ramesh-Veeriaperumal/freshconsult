class ContactFilterValidation < FilterValidation
  attr_accessor :state, :phone, :mobile, :email, :company_id, :conditions, :tag, :_updated_since

  validates :state, custom_inclusion: { in: ContactConstants::STATES }
  validates :email, data_type: { rules: String }
  validates :email, custom_format: { with: ApiConstants::EMAIL_VALIDATOR, accepted: :'valid email address', allow_nil: true }

  validates :company_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validate :check_company, if: -> { company_id && errors[:company_id].blank? }
  validates :phone, :mobile, data_type: { rules: String }
  validates :tag, data_type: { rules: String }, custom_length: { maximum: ApiConstants::TAG_MAX_LENGTH_STRING }
  validates :_updated_since, date_time: true

  def initialize(request_params, item = nil, allow_string_param = true)
    @conditions = (request_params.keys & ContactConstants::INDEX_FIELDS)
    filter_name = request_params.fetch('state', 'default')
    @conditions = @conditions - ['tag'] - ['state'] + [filter_name].compact
    super(request_params, item, allow_string_param)
  end

  def check_company
    company = Account.current.companies.find_by_id(@company_id)
    errors[:company_id] << :"can't be blank" unless company
  end
end
