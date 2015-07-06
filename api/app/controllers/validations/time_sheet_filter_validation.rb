class TimeSheetFilterValidation < ApiValidation
  attr_accessor :company_id, :user_id, :billable, :executed_after, :executed_before, :company, :user, :group_id, :group

  validates :billable, included: { in: ApiConstants::BOOLEAN_VALUES }, allow_blank: true
  validates :executed_after, :executed_before, date_time: { allow_nil: true }
  validates :user_id, :company_id, :group_id, numericality: { allow_nil: true }
  validates :company, presence: true, if: -> { company_id && errors[:company_id].blank? }
  validates :user, presence: true, if: -> { user_id && errors[:user_id].blank? }
  validates :group, presence: true, if: -> { group_id && errors[:group_id].blank? }

  def initialize(filter_params, item)
    super(filter_params, item)
    @company = Account.current.companies_from_cache.find { |x| x.id == @company_id.to_i } if  @company_id && errors[:company_id].blank?
    @user = Account.current.agents_from_cache.find { |x| x.user_id == @user_id.to_i } if  @user_id && errors[:user_id].blank?
    @group = Account.current.groups_from_cache.find { |x| x.id == @group_id.to_i } if  @group_id && errors[:group_id].blank?
  end
end
