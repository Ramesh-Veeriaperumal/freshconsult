class ExportCsvValidation < ApiValidation
  attr_accessor :default_fields, :custom_fields, :fields

  validates :fields, data_type: { rules: Hash, allow_nil: false }, required: true, if: -> { contact_or_company? }
  validates :default_fields,
    data_type: { rules: Array, allow_nil: false },
    array: {
      data_type: { rules: String },
      custom_inclusion: { in: proc { |x| x.default_field_names } }
    }

  validates :custom_fields,
    data_type: { rules: Array, allow_nil: false },
    array: {
      data_type: { rules: String },
      custom_inclusion: { in: proc { |x| x.custom_field_names } }
    }

  validate :validate_request_params, if: -> { errors.blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def default_field_names
    Account.current.safe_send("#{@export_type}_form")
           .safe_send("default_#{@export_type}_fields").map(&:name)
  end

  def custom_field_names
    Account.current.safe_send("#{@export_type}_form").
        safe_send("custom_#{@export_type}_fields").map(&:name).collect { |x| x[3..-1] }
  end

  def validate_request_params
    errors[:request] << :select_a_field if [*default_fields, *custom_fields].empty?
    if [*default_fields, *custom_fields].length > ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS
      errors[:request] << :fields_limit_exceeded
      error_options.merge!(request: { max_count: ApiConstants::MAX_CUSTOMER_EXPORT_FIELDS })
    end
  end

  def default_company_fields
    Account.current.company_form.default_company_fields.map(&:name)
  end

  def custom_company_fields
    Account.current.company_form.custom_company_fields.collect { |x| display_name(x.name) }
  end

  def default_contact_fields
    Account.current.contact_form.default_contact_fields(true).map(&:name)
  end

  def custom_contact_fields
    Account.current.contact_form.custom_contact_fields.collect { |x| display_name(x.name) }
  end

  def customer_export_privilege?
    User.current.privilege?(:export_customers)
  end

  def display_name(name, type = nil)
    return name[0..(-Account.current.id.to_s.length - 2)] if type == :ticket
    name[3..-1]
  end

  def contact_or_company?
    ['contact', 'company'].include?(@export_type)
  end
end
