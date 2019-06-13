module SBRR
  module Config
    class Skill < BaseWorker

      sidekiq_options queue: :sbrr_config_skill,
                      retry: 0,
                      failures: :exhausted

      def perform args
      	args.symbolize_keys!
        #the user queue sync will happen via user_skill destroy callback when the skill is deleted
        disassociate_tickets_with_skill args[:skill_id] if args[:action].to_sym == :destroy
      end

      private

        def disassociate_tickets_with_skill skill_id
          ticket_ids = []
          tickets_eligible_for_sbrr_and_unassigned(skill_id).find_each({:batch_size => 500}) do |ticket|
            ticket_ids << ticket.id
            trigger_sbrr ticket
          end
          #Tickets which are not eligible for sbrr and (eligible for sbrr + assigned) will be updated below
          trigger_update_all_with_publish ticket_ids, skill_id
        end

        def tickets_eligible_for_sbrr_and_unassigned skill_id
          status_ids = sla_on_status_ids
          sbrr_group_ids = Account.current.groups.skill_based_round_robin_enabled.pluck(:id)
          tickets.associated_with_skill(skill_id).unassigned.visible.sla_on_tickets(status_ids).where(group_id: sbrr_group_ids)        
        end

        def trigger_update_all_with_publish ticket_ids, skill_id
          reason = {:skill_deleted => [skill_id]}
          options = {:reason => reason, :manual_publish => true}
          tickets.associated_with_skill(skill_id).where("helpdesk_tickets.id NOT IN (?)", ticket_ids).update_all_with_publish({ sl_skill_id: nil }, {}, options)
        end

        def sla_on_status_ids
          Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
        end

        def tickets
          Account.current.tickets
        end

        def trigger_sbrr ticket
          ticket.sl_skill_id = nil
          #args = {:model_changes => {}, :ticket_id => ticket.display_id, :attributes => ticket.sbrr_attributes, :sbrr_state_attributes => ticket.sbrr_state_attributes, :options => {:action => "skill_deleted", :jid => self.jid}}
          args = {:model_changes => {}, :options => {:action => "skill_deleted", :jid => self.jid}}
          sbrr_executor(ticket, args).execute 
        end

        def sbrr_executor ticket, args
          SBRR::Execution.enqueue ticket, args
          #SBRR::Execution.new args
        end        
    end
  end
end
