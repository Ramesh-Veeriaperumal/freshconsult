class BadRequestError < BaseError
  attr_accessor :code, :field, :http_code, :nested_field, :additional_info

  MODEL_ERROR_MAP = {
    :"can't be blank" => :absent_in_db,
    :'should be a valid email address' => :absent_in_db,
    :inaccessible_value => :inaccessible_value,
    :translation_available_already => :translation_available_already,
    :translation_not_available => :translation_not_available,
    :"is invalid" => :absent_in_db,
    :"cannot_create_new_tag" => :"cannot_create_new_tag: %{tags}"
  }.freeze

  ATTRIBUTE_RESOURCE_MAP = {
    requester_id: :contact,
    company_id: :company,
    agent_id: :agent,
    escalate_to: :agent,
    email: :contact,
    product_id: :product,
    group_id: :group,
    responder_id: :agent,
    user_id: :contact,
    forum_id: :forum,
    forum_category_id: :category,
    email_config_id: :email_config,
    from_email: :"active email_config",
    scenario_id: :scenario,
    category_name: :category,
    folder_name: :folder,
    ticket_id: :ticket,
    responder_phone: :agent,
    application_id: :application,
    note_id: :note,
    filter: :ticket_filter,
    responder_ids: :agent,
    group_ids: :group,
    product_ids: :product,
    status_ids: :status,
    parent_template_id: :parent_template,
    child_template_ids: :child_template,
    tags: :tags
  }.freeze

  def initialize(attribute, value, params_hash = {})
    placeholders = params_hash.key?(attribute) ? params_hash[attribute] : params_hash
    @code = placeholders[:code] || ErrorConstants::API_ERROR_CODES_BY_VALUE[value] || ErrorConstants::DEFAULT_CUSTOM_CODE
    @field = attribute
    @nested_field = placeholders[:nested_field]
    @additional_info = placeholders[:additional_info]
    @http_code = ErrorConstants::API_HTTP_ERROR_STATUS_BY_CODE[@code] || ErrorConstants::DEFAULT_HTTP_CODE
    value, placeholders = format_model_error(value, attribute, placeholders) if MODEL_ERROR_MAP.key?(value) && ATTRIBUTE_RESOURCE_MAP.key?(attribute)
    super(value, placeholders) # params hash is used for sending param to translation.
  end

  def format_model_error(value, attribute, placeholders)
    value = MODEL_ERROR_MAP[value]
    placeholders = placeholders.merge!(attribute: attribute, resource: ATTRIBUTE_RESOURCE_MAP[attribute])
    [value, placeholders]
  end
end
