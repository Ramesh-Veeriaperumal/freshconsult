class LeaderboardValidation < ApiValidation
  attr_accessor :group_id, :date_range

  validates :group_id, custom_numericality: { only_integer: true, greater_than: -1, allow_nil: true, ignore_string: :allow_string_param }

  validates :date_range, data_type: { rules: String }, custom_inclusion: { in: ApiLeaderboardConstants::DATE_RANGE_OPTIONS}
end