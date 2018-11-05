class RoleBulkUpdateValidation < ApiValidation
  attr_accessor :options

  validates :options, required: true, data_type: { rules: Hash, allow_nil: false }

  validate :validate_options, if: -> { errors.blank? }

  def initialize(request_params, item = nil, allow_string_param = false)
    super(request_params)
  end

  private

  def validate_options
    options_valid = options.present? && RoleConstants::ALLOWED_BULK_UPDATE_OPTIONS.any? {|property| valid_property?(property)}
    errors[:options] << :select_a_field unless options_valid
  end

  def valid_property?(property)
    update_option = options[property]
    valid = update_option.present? && (update_option[:add].present? || update_option[:remove].present?)
    safe_send("validate_#{property}", update_option) if valid
    valid
  end

  def validate_privileges(update_option)
    privilege_options = (update_option[:remove].to_a + update_option[:add].to_a).map(&:to_sym).uniq
    check_invalid_privileges(privilege_options)
    check_unauthorized_privileges(privilege_options)
  end

  def check_invalid_privileges(privilege_options)
    invalid_privileges = privilege_options - PRIVILEGES_BY_NAME
    if invalid_privileges.present?
      errors[:privileges] << :no_matching_privilege
      (@error_options ||= {}).merge!(privileges: { list: invalid_privileges.join(', ') })
    end
  end

  def check_unauthorized_privileges(privilege_options)
    unauthorized_privileges = RoleConstants::RESTRICTED_PRIVILEGES.select { |privilege|
      privilege_options.include?(privilege) && !User.current.privilege?(privilege)
    }
    if unauthorized_privileges.present?
      errors[:privileges] << :invalid_privilege_list
      (@error_options ||= {}).merge!(privileges: { list: unauthorized_privileges.join(', ') })
    end
  end
end
