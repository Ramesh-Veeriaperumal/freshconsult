class CustomTicketFilterValidation < FilterValidation
  
  attr_accessor :name, :order, :order_type, :query_hash, :visibility, :visibility_id, :group_id

  validates :name, required: true, data_type: { rules: String }, custom_length: { maximum: ApiConstants::MAX_LENGTH_STRING }
  validates :order, required: true, custom_inclusion: { in: ApiTicketConstants::ORDER_BY }
  validates :order_type, required: true, custom_inclusion: { in: ApiTicketConstants::ORDER_TYPE }
  validates :query_hash, required: true, data_type: { rules: Array, allow_nil: false }
  validates :query_hash, required: true, array: { data_type: { rules: Hash, allow_nil: false } }
  validates :visibility, data_type: { rules: Hash }
  validates :visibility_id, data_type: { rules: Integer }, custom_inclusion: { in: Admin::UserAccess::VISIBILITY_NAMES_BY_KEY.keys }
  validates :group_id, data_type: { rules: Integer }, if: -> { visibility_id == Admin::UserAccess::VISIBILITY_KEYS_BY_TOKEN[:group_agents] }

  validates :visibility, required: true, on: :create
  validates :visibility_id, required: true, on: :create
  validates :group_id, required: true, on: :create

  validate :query_hash_integrity
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

  def query_hash_integrity
    return unless query_hash.present? && query_hash.is_a?(Array)
    query_hash_errors = []
    query_hash.each_with_index do |query, index|
      query_hash_validator = ::QueryHashValidation.new(query)
      query_hash_errors << query_hash_validator.errors.full_messages unless query_hash_validator.valid?
    end
    if query_hash_errors.present?
      errors[:query_hash] << :"invalid_query_conditions"
    end
  end

  def group_id_validation
    unless Account.current.groups_from_cache.map(&:id).include?(group_id)
      errors[:group_id] << :"invalid_group_id"
    end
  end

end
