class RoleDelegator < BaseDelegator

  validate :validate_default_roles
  validate :validate_missing_privileges

  def initialize(record, options = {})
    super(record, options)
    instance_variable_set("@role_options", options)
  end

  def validate_missing_privileges
    privilege_list = self.privilege_list
    invalid_privileges = RoleConstants::PRIVILEGE_DEPENDENCY_MAP.each_with_object([]) { |(key, value), privileges|
      privileges << key if check_privilege_dependency(key, value, privilege_list)
    }
    if invalid_privileges.present?
      errors[:privilege_list] << :missing_privileges
      (@error_options ||= {}).merge!(privilege_list: { list: invalid_privileges.join(', ') })
    end
  end

  def validate_default_roles
    privileges_list = @role_options[:privileges]
    if default_role && privileges_list.present?
      invalid_privilege_update = !private_api? || ((privileges_list[:add].to_a + privileges_list[:remove].to_a).uniq -
        RoleConstants::DEFAULT_ROLE_UPDATABLE_PRIVILEGES[name].to_a).present?
      errors[:id] << :default_role_modified if invalid_privilege_update
    end
  end

  private

    def check_privilege_dependency(key, value, privilege_list)
      base_privilege_present = privilege_list.include?(key)
      dependent_privileges_present = (value & privilege_list).present?
      (key == RoleConstants::VIEW_ADMIN_PRIVILEGE && base_privilege_present && !dependent_privileges_present) ||
        (dependent_privileges_present && !base_privilege_present)
    end
end