['roles_helper.rb'].each { |file| require "#{Rails.root}/spec/support/#{file}" }
module RolesTestHelper
  include RolesHelper
  # Patterns
  def role_pattern(expected_output = {}, role)
    {
      id: Fixnum,
      name: expected_output[:name] || role.name,
      description: expected_output[:description] || role.description,
      default: expected_output[:description] || role.default_role,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end
