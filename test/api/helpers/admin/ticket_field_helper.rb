module Admin::TicketFieldHelper

  def launch_ticket_field_revamp
    begin
      @account.launch :ticket_field_revamp
      yield
    rescue => e
      p e
    ensure
      @account.rollback :ticket_field_revamp
    end
  end


  def default_field_deletion_error_message?(tf)
    {
      'description' => 'Validation failed',
      'errors' => [
        {
          'field' => tf.name,
          'message' => "Default field '#{tf.name}' can't be deleted",
          'code' => 'invalid_value'
        }
      ]
    }
  end
end
