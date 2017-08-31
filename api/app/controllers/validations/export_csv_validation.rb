class ExportCsvValidation < ApiValidation
  attr_accessor :default_fields, :custom_fields

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
    Account.current.contact_form.default_fields.map(&:name) - ['tag_names']
  end

  def custom_field_names
    Account.current.contact_form.custom_fields.map(&:name).collect { |x| x[3..-1] }
  end

  def validate_request_params
    errors[:request] << :select_a_field if [*default_fields, *custom_fields].empty?
  end

  def default_company_fields
    Account.current.company_form.default_company_fields.map(&:name)
  end

  def custom_company_fields
    Account.current.company_form.custom_company_fields.collect { |x| display_name(x.name) }
  end

  def default_contact_fields
    Account.current.contact_form.default_contact_fields(true).map(&:name) - ['tag_names']
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
end
