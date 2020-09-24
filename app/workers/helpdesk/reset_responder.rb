class Helpdesk::ResetResponder < BaseWorker

  include Redis::RedisKeys
  include Redis::OthersRedis
  include BulkOperationsHelper

  sidekiq_options :queue => :reset_responder, :retry => 0, :failures => :exhausted
  BATCH_LIMIT = 50

  def perform(args)
    begin
      args.symbolize_keys!
      @account     = Account.current
      user_id      = args[:user_id]
      @user        = @account.all_users.find_by_id(user_id)
      reason       = args[:reason].symbolize_keys!
      options      = { reason: reason, manual_publish: true, rate_limit: rate_limit_options(args) }
      return if @user.nil?

      Sharding.run_on_slave do
        ticket_ids = fetch_ticket_ids_for_automatic_assignment
        handle_agent_tickets(options)
        handle_automatic_ticket_assignments(ticket_ids) if ticket_ids.present?
      end
    rescue Exception => e
      NewRelic::Agent.notice_error(e, args: args)
    end
  end

  private

    def fetch_ticket_ids_for_automatic_assignment
      ticket_ids = []
      if @account.automatic_ticket_assignment_enabled?
        status_ids = Helpdesk::TicketStatus.sla_timer_on_status_ids(@account)
        group_ids = fetch_auto_ticket_assign_groups
        @account.tickets.visible.sla_on_tickets(status_ids).where(group_id: group_ids).assigned_to(@user).select('id').find_in_batches do |tickets|
          ticket_ids << tickets.map(&:id)
        end
      end
      ticket_ids.flatten!
    end

    def handle_automatic_ticket_assignments(ticket_ids = [])
      return unless @account.automatic_ticket_assignment_enabled?

      Sharding.run_on_master { reassign_tickets(ticket_ids) }
    end

    def handle_agent_tickets(options)
      @account.tickets
              .where(responder_id: @user.id)
              .update_all_with_publish({ responder_id: nil }, {}, options)
    end

    def fetch_auto_ticket_assign_groups
      @account.groups_from_cache.select(&:automatic_ticket_assignment_enabled?).map(&:id)
    end

    def reassign_tickets(ticket_ids)
      ocr_enabled = @account.omni_channel_routing_enabled?

      ticket_ids.each_slice(100).each do |ticket_ids_slice|
        @account.tickets.where('id in (?)', ticket_ids_slice).preload(:group).find_each do |ticket|
          if ticket.group.try(:skill_based_round_robin_enabled?)
            trigger_sbrr ticket
          elsif ocr_enabled && ticket.group.omni_channel_routing_enabled? && ticket.eligible_for_ocr?
            ticket.sync_task_changes_to_ocr(nil)
          elsif ticket.group.capping_enabled?
            ticket.assign_tickets_to_agents
          end
        end
      end
    end

    def trigger_sbrr(ticket)
      ticket.sbrr_fresh_ticket = true
      args = {
        model_changes: {},
        options: {
          action: 'reset_responder', jid: jid
        }
      }
      SBRR::Execution.enqueue(ticket, args).execute if ticket.eligible_for_round_robin?
    end
end
