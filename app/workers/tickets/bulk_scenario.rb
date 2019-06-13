module Tickets
  class BulkScenario < BaseWorker

    sidekiq_options :queue => :bulk_scenario, :retry => 0, :failures => :exhausted
    include Helpdesk::BulkActionMethods

    def perform(args)
      Thread.current[:sbrr_log] = [self.jid]
      args.symbolize_keys!
      current_account = Account.current
      current_user = User.current
      va_rule = execute_on_db {current_account.scn_automations.find_by_id(args[:scenario_id])}
      return if current_user.nil? or current_account.nil? or va_rule.nil?
      ids = args[:ticket_ids]
      ids_join = ids.length > 0 ? ids.join(',') : '1'#'1' is dummy to prevent error
      @items = execute_on_db {current_account.tickets.order("field(display_id, #{ids_join})").where(:display_id => ids)}
      @items.each do |ticket|
        begin
          va_rule.trigger_actions(ticket, current_user)
          bulk_update_tickets(ticket) { ticket.save }
          Va::RuleActivityLogger.clear_activities
          ticket.create_scenario_activity(va_rule.name)
        rescue Exception => e
          logger.info "#{e}"
          logger.info "::::::::::::::::::::error:::::::::::::#{va_rule.inspect}"
          logger.info ticket.inspect
          NewRelic::Agent.notice_error(e,{:description => "Error while executing scenario automations for a tkt :: #{ticket.id} :: account :: #{current_account.id}" })
        end
      end
    rescue Exception => e
      logger.info "#{e}"
      logger.info e.backtrace.join("\n")
      logger.info "something is wrong: #{e.message}"
      NewRelic::Agent.notice_error(e)
    ensure
      bulk_sbrr_assigner
      User.reset_current_user
      Thread.current[:sbrr_log] = nil
    end
  end
end
