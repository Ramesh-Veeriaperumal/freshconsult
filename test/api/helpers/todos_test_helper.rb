module TodosTestHelper

  def todo_pattern(expected_output = {})
    response = {
      id:  expected_output[:todo_id],
      body: expected_output[:body],
      completed: expected_output[:completed] || false,
      user_id: User.current.id,
      ticket_id: nil,
      ticket_subject: expected_output[:ticket_subject],
      contact_id: nil,
      contact_name: expected_output[:contact_name],
      company_id: expected_output[:company_id],
      company_name: expected_output[:company_name],
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
    if expected_output[:type]
      response[:"#{expected_output[:type]}_id"] = expected_output[:rememberable_id]
    end
    response
  end

  def scoper
    Helpdesk::Reminder
  end

  def get_new_reminder(body, ticket_id = nil,
    contact_id = nil, company_id = nil, user_id = User.current.id)
    rem = scoper.new(body: body)
    rem.ticket_id = ticket_id
    rem.user_id = user_id
    rem.contact_id = contact_id
    rem.company_id = company_id
    rem.save
    rem
  end

  def merge_error_pattern(errors)
    {
      description: 'Validation failed',
      errors: errors
    }
  end

  def merge_invalid_field_pattern(field_name)
    error = {
      field: field_name,
      message: 'Unexpected/invalid field in request',
      code: 'invalid_field'
    }
    merge_error_pattern([error])
  end

  def merge_invalid_value_pattern(field_name, message)
    error = {
      field: field_name,
      message: message,
      code: 'invalid_value'
    }
    merge_error_pattern([error])
  end
end
