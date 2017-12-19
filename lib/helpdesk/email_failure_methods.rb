module Helpdesk::EmailFailureMethods

  def dynamodb_range_key
    email_failures[:dynamodb_range_key]
  end

  def dynamodb_range_key=(value)
    email_failures[:dynamodb_range_key] = value.to_i
  end

  def failure_count
    email_failures[:failure_count]
  end

  def failure_count=(value)
    email_failures[:failure_count] = value.to_i
  end

end

