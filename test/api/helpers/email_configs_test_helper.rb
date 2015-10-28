module Helpers::EmailConfigsTestHelper
  include EmailConfigsHelper

  def email_config_pattern(expected_output = {}, email_config)
    expected_output[:ignore_created_at] ||= true
    expected_output[:ignore_updated_at] ||= true
    {
      id: Fixnum,
      name: expected_output[:name] || email_config.name,
      to_email: email_config.to_email,
      reply_email: email_config.reply_email,
      primary_role: email_config.primary_role.to_s.to_bool,
      active: email_config.active.to_s.to_bool,
      product_id: email_config.product_id,
      group_id: email_config.group_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end
end
