class CustomerImportValidation < ApiValidation
  include CustomerImportConstants

  attr_accessor :file, :fields

  validates :fields, data_type: { rules: Hash, allow_nil: false },
                     required: true

  validates :file, required: true
  validates_each :file, on: :create do |record, attr, value|
    if value && !CSV_FILE_EXTENSION_REGEX.match(value.original_filename)
      record.errors.add(attr,
          ErrorConstants::ERROR_MESSAGES[:invalid_format] % ACCEPTED_FILE_TYPE)
    end
  end

  validate :check_field_names, if: -> { errors[:fields].blank? }

  validate :check_field_values, if: -> { errors[:fields].blank? }

  def initialize(request_params, item, allow_string_param = false)
    super(request_params, item, allow_string_param)
  end

  def check_field_names
    form = Account.current.safe_send("#{@import_type}_form")
    field_names = form.safe_send("#{@import_type}_fields").map(&:name)
    field_names << form.fetch_client_manager_field.name if @import_type == 'contact'
    invalid_values = (fields.keys.map &:to_sym) - (field_names.map &:to_sym)
    unless invalid_values.empty?
      errors[:fields] << :invalid_import_fields
      error_options[:fields] = { invalid_values: invalid_values }
    end
  end

  def check_field_values
    errors[:fields] << :invalid_import_value unless fields.values.all? { |value| value !~ /\D/ }
  end
end
