module Tickets
  class BulkScenario < BaseWorker

    sidekiq_options :queue => :bulk_scenario, :retry => 0, :backtrace => true, :failures => :exhausted
    
    def perform(args)
      args.symbolize_keys!
      current_account = Account.current
      current_user = User.current
      va_rule = execute_on_db {current_account.scn_automations.find_by_id(args[:scenario_id])}
      return if current_user.nil? or current_account.nil? or va_rule.nil?
      tickets = execute_on_db {current_account.tickets.where(:display_id => args[:ticket_ids])}
      tickets.each do |ticket|
        begin
          va_rule.trigger_actions(ticket, current_user)
          ticket.save
          Va::ScenarioFlashMessage.clear_activities
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
      User.reset_current_user
    end
  end
end