['roles_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module RolesTestHelper
  include RolesHelper
  # Patterns
  def role_pattern(expected_output = {}, role)
    role_hash = {
      id: Integer,
      name: expected_output[:name] || role.name,
      description: expected_output[:description] || role.description,
      default: expected_output[:default] || role.default_role,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    role_hash[:agent_type] = expected_output[:agent_type] || role.agent_type if Account.current.launched?(:collaboration_roles)
    role_hash
  end

  def private_role_pattern(expected_output = {}, role)
    role_hash = {
      id: Integer,
      name: expected_output[:name] || role.name,
      description: expected_output[:description] || role.description,
      default: expected_output[:default] || role.default_role,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      privileges: expected_output[:privilege_list] || role.privilege_list
    }
    role_hash[:agent_type] = expected_output[:agent_type] || role.agent_type if Account.current.launched?(:collaboration_roles)
    role_hash
  end
end
