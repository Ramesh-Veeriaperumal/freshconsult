class Import::SimpleOutreachWorker < Import::ContactWorker
  sidekiq_options :queue => :simple_outreach_import, :retry => 0, :backtrace => true,
                  :failures => :exhausted

  def perform(args)
    args.symbolize_keys!
    acc = Account.current
    spam_account_check(args)
    Rails.logger.info "Proactive contact import started : #{args[:rule_id]} : #{Account.current.id}"
    contact_ids = Import::Customers::OutreachContact.new(args).import
    Rails.logger.info "Proactive contact import completed : #{args[:rule_id]} : #{Account.current.id} : #{contact_ids.length}"
    ::Proactive::SimpleOutreachUpdate.new(contact_ids, args[:rule_id]).make_proactive_service_call
  end
end
