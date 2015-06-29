class TimeSheetFilterValidation < ApiValidation
  attr_accessor :company_id, :user_id, :billable, :executed_after, :executed_before, :group_id

  validates :billable, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :executed_after, :executed_before, date_time: { allow_nil: true }
  validate :valid_company_id?, if: -> { company_id }
  validate :valid_user_id?, if: -> { user_id }
  validate :valid_group_id?, if: -> { group_id }

  def initialize(filter_params, item)
    super(filter_params, item)
  end

  def valid_company_id?
    errors.add(:company_id, "can't be blank") unless Account.current.companies_from_cache.any? { |x| x.id == @company_id.to_i }
  end

  def valid_user_id?
    errors.add(:user_id, "can't be blank") unless Account.current.agents_from_cache.any? { |x| x.user_id == @user_id.to_i }
  end

  def valid_group_id?
    errors.add(:group_id, "can't be blank") unless Account.current.groups_from_cache.any? { |x| x.id == @group_id.to_i }
  end
end
