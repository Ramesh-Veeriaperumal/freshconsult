class SatisfactionRatingFilterValidation < FilterValidation
  attr_accessor :created_since, :user_id, :conditions

  validates :user_id, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }

  validates :created_since, date_time: true

  validate :verify_user, if: -> { user_id && errors[:user_id].blank? }

  def initialize(request_params, item = nil, allow_string_param = true)
    @conditions = (SurveyConstants::INDEX_FIELDS & request_params.keys)
    @conditions = ['default'] if @conditions.empty?
    super(request_params, item, allow_string_param)
  end

  def verify_user
    user = Account.current.all_users.detect { |u| u.id == @user_id.to_i }
    errors[:user_id] << :"can't be blank" unless user
  end
end
