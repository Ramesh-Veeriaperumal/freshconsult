class Integrations::TicketSummary
  def current_account
    @account ||= Account.current
  end

  def enable_ticket_summary(inst_app)
    Rails.logger.info "Enable feature :: ticket_summary"
    current_account.add_feature(:ticket_summary)
  end

  def disable_ticket_summary(inst_app)
    Rails.logger.info "Disable feautre :: ticket_summary"
    current_account.revoke_feature(:ticket_summary)
  end
end

