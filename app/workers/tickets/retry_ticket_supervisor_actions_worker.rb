# frozen_string_literal: true

module Tickets
  class RetryTicketSupervisorActionsWorker < Admin::SupervisorWorker
    sidekiq_options queue: :retry_ticket_supervisor_actions_worker, retry: 0, failures: :exhausted
    RETRY_SUPERVISOR_ERROR = 'RETRY_SUPERVISOR_EXECUTION_FAILED'

    def perform(args)
      args.symbolize_keys!
      Rails.logger.info "Retrying supervisor actions for account :: #{Account.current.id}, ticket :: #{args[:ticket_id]}, rule :: #{args[:rule_id]}"
      rule = Account.current.supervisor_rules.find(args[:rule_id])
      ticket = Account.current.tickets.find(args[:ticket_id])
      if can_be_retried?(rule, ticket)
        execute_actions(rule, ticket, true)
      else
        Rails.logger.info("Rule not matched for ticket when retrying supervisor. account :: #{Account.current.id}, ticket :: #{args[:ticket_id]}, rule :: #{args[:rule_id]}")
      end
    rescue StandardError => e
      log_info(Account.current.id, rule.id) { Va::Logger::Automation.log_error(RETRY_SUPERVISOR_ERROR, e) }
      NewRelic::Agent.notice_error(e)
    end

    private

    def can_be_retried?(rule, ticket)
      account_negatable_columns = ::VAConfig.negatable_columns(Account.current)
      conditions = []
      conditions = rule.filter_query
      return false if conditions.empty?
      negate_conditions = [""]
      negate_conditions = rule.negation_query(account_negatable_columns)
      joins = rule.get_joins(["#{conditions[0]} #{negate_conditions[0]}"])
      Account.current.tickets.where(negate_conditions).where(conditions).where(id: ticket.id).updated_in(1.month.ago)
      .visible.joins(joins).exists?
    end
  end
end
