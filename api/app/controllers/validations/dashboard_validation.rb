class DashboardValidation < ApiValidation

  attr_accessor :group_ids, :product_ids, :status_ids, :group_by, :responder_ids, :before_id, :page, :per_page, :since_id

  validates :group_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0,  allow_nil: true, ignore_string: :allow_string_param } }
  validates :product_ids, data_type: { rules: Array}, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param } }
  validates :status_ids, data_type: { rules: Array }, array: { custom_numericality: { only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param } }
  validates :group_by, required: true, data_type: { rules: String }, custom_inclusion: { in: ApiDashboardConstants::UNRESOLVED_GROUP_BY_OPTIONS }, on: :unresolved_tickets_data
  validates :responder_ids, data_type: { rules: Array }, array: { custom_numericality: {only_integer: true, greater_than: 0, allow_nil: true, ignore_string: :allow_string_param } }
  validates :before_id, :since_id, :page, :per_page, custom_numericality: { only_integer: true, greater_than: 0, ignore_string: :allow_string_param }
  validate :since_id_or_before_id

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def since_id_or_before_id
    if since_id.present? && before_id.present?
      errors[:since_id_or_before_id] << :either_since_id_or_before_id
    end
  end
end
