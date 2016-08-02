class AgentDelegator < BaseDelegator
  attr_accessor :group_ids, :role_ids

  validate :validate_group_ids, if: -> { self[:group_ids] }
  validate :validate_role_ids, if: -> { self[:role_ids] }

  def validate_role_ids
    invalid_roles = self[:role_ids].map(&:to_i) - Account.current.roles_from_cache.map(&:id)
    if invalid_roles.present?
      errors[:role_ids] << :invalid_list
      (@error_options ||= {}).merge!(role_ids: { list: invalid_roles.join(', ') })
    end
  end

  def validate_group_ids
    invalid_groups = self[:group_ids].map(&:to_i) - Account.current.groups_from_cache.map(&:id)
    if invalid_groups.present?
      errors[:group_ids] << :invalid_list
      (@error_options ||= {}).merge!(group_ids: { list: invalid_groups.join(', ') })
    end
  end
end
