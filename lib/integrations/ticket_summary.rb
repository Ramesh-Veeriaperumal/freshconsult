class Integrations::TicketSummary
  def current_account
    @account ||= Account.current
  end

  def enable_ticket_summary(inst_app)
    Rails.logger.info "Enable feature :: ticket_summary"
    current_account.enable_setting(:ticket_summary)
  end

  def disable_ticket_summary(inst_app)
    Rails.logger.info 'Disable feature :: ticket_summary'
    current_account.disable_setting(:ticket_summary)
  end
end

