module TodosTestHelper
  def todo_pattern(todo, expected_output = {})
    {
      id: todo.id,
      body: expected_output[:body] || todo.body,
      completed: expected_output[:deleted] || todo.deleted,
      user_id: todo.user_id,
      ticket_id: expected_output[:ticket_id] || todo.ticket_id,
      created_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$},
      updated_at: %r{^\d\d\d\d[- \/.](0[1-9]|1[012])[- \/.](0[1-9]|[12][0-9]|3[01])T\d\d:\d\d:\d\dZ$}
    }
  end

  def scoper
    Helpdesk::Reminder
  end

  def get_new_reminder(body, ticket_id)
    rem = scoper.new(body: body)
    rem.ticket_id = ticket_id
    rem.user_id = User.current.id
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
