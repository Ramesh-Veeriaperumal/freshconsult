class CustomTicketFilterValidation < FilterValidation
  attr_accessor :name, :order_by, :order_type, :query_hash, :visibility, :visibility_id, :group_id

  validates :name, required: true, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :order_by, required: true, custom_inclusion: { in: proc { |x| x.sort_field_options } }
  validates :order_type, required: true, custom_inclusion: { in: ApiConstants::ORDER_TYPE }
  validates :query_hash, data_type: { required: true, rules: Array, allow_nil: false }
  validates :query_hash, array: { data_type: { rules: Hash, allow_nil: false } }
  validates :visibility, data_type: { rules: Hash }
  validates :visibility_id, data_type: { rules: Integer }, custom_inclusion: { in: Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys }
  validates :group_id, data_type: { rules: Integer }, if: -> { visibility_id == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents] }

  validates :visibility, required: true, on: :create
  validates :visibility_id, required: true, on: :create
  validates :group_id, required: true, on: :create

  validate :validate_query_hash, if: -> { query_hash.present? }
  validate :group_id_validation, if: -> { visibility_id && visibility_id == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents] }

  def initialize(request_params, item = nil, allow_string_param = false)
    @request_params = request_params
    if request_params.key?(:visibility)
      self.visibility ||= request_params[:visibility]
      if self.visibility.present? && self.visibility.is_a?(Hash)
        self.visibility_id ||= visibility[:visibility] if visibility.key?(:visibility)
        self.group_id ||= visibility[:group_id] if visibility.key?(:group_id)
      end
    end
    super(request_params.except(:visibility), item, allow_string_param)
  end

  def group_id_validation
    unless Account.current.groups_from_cache.map(&:id).include?(group_id)
      errors[:group_id] << :invalid_group_id
    end
  end

  def sort_field_options
    TicketsFilter.api_sort_fields_options.map(&:first).map(&:to_s)
  end
end
