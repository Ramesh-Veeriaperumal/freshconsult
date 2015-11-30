module Helpers::ProductsTestHelper
  include ProductsHelper
  # Patterns
  def product_pattern(expected_output = {}, product)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || product.name,
      description: expected_output[:description] || product.description,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end
