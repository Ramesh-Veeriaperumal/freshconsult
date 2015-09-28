class TimeEntryFilterValidation < ApiValidation
  attr_accessor :company_id, :agent_id, :billable, :executed_after, :executed_before

  validates :billable, data_type: { rules: 'Boolean', allow_blank: true }
  validates :executed_after, :executed_before, date_time: { allow_nil: true }
  validates :agent_id, :company_id, numericality: { allow_nil: true, only_integer: true }
  validate :valid_user?, if: -> { agent_id && errors[:agent_id].blank? }
  validate :valid_company?, if: -> { company_id && errors[:company_id].blank? }

  def initialize(filter_params, item)
    super(filter_params, item)
  end

  def valid_user?
    user = Account.current.agents_from_cache.detect { |x| x.user_id == @agent_id.to_i }
    errors.add(:agent_id, "can't be blank") unless user
  end

  def valid_company?
    user = Account.current.companies_from_cache.detect { |x| x.id == @company_id.to_i }
    errors.add(:company_id, "can't be blank") unless user
  end
end
