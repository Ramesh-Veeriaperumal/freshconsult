class PasswordPolicyDecorator < ApiDecorator
  delegate :policies, :configs, to: :record

  def to_hash
    return { policies: nil } unless record.is_a?(PasswordPolicy)
    ret_hash = { 
      policies: configs
    }
    policies.map(&:to_s).each do |policy|
      ret_hash[:policies][policy] = true unless configs.key?(policy)
    end
    ret_hash
  end
end
