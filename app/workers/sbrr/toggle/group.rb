module SBRR
  module Toggle
    class Group < BaseWorker

      sidekiq_options queue: :sbrr_group_toggle,
                      retry: 0,
                      failures: :exhausted

      def perform args
        Thread.current[:sbrr_log] = [self.jid]
        @args  = args.symbolize_keys
        init @args[:group_id]
        if @args[:capping_limit_change].present?
          refresh_user_scores #user queues should be first
          sbrr_resource_allocator_for_ticket_queue(:capping_limit_increase) if @args[:capping_limit_change] == 'increased'
        else #turned on
          update_users_in_queues #user queues should be first
          trigger_sbrr_for_unassigned_tickets
        end
      ensure
        Thread.current[:sbrr_log] = nil
      end

      def init group_id
        @group = Account.current.groups.where({:id => group_id}).limit(1).first
      end

      def refresh_user_scores
        user_toggle_synchronizers.each do |user_toggle_synchronizer|
          user_toggle_synchronizer.refresh
        end        
      end

      def update_users_in_queues
        user_toggle_synchronizers.each do |user_toggle_synchronizer|
          user_toggle_synchronizer.sync @group.skill_based_round_robin_enabled?
        end
      end

      def sbrr_resource_allocator_for_ticket_queue action
        Thread.current[:mass_assignment] = action
        SBRR::ResourceAllocator::TicketQueue.new(nil, :group => @group).allocate
      rescue Exception => e
        SBRR.log("Exception in group #{@group.id} trigger_assign_user_for_tickets_in_queue #{e.message}")
      ensure
        Thread.current[:mass_assignment] = nil
      end

      def trigger_sbrr_for_unassigned_tickets
        status_ids   = Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
        @group.tickets.visible.sla_on_tickets(status_ids).find_each({:batch_size => 300, :conditions => "responder_id IS NULL"}) do |ticket|
          trigger_sbrr ticket
        end
      end

      private

        def trigger_sbrr ticket
          #args = {:model_changes => {},:ticket_id => ticket.display_id, :sbrr_state_attributes => ticket.sbrr_state_attributes, :attributes => { :sbrr_turned_on => true }, :options => {:action => "sbrr_turned_on_for_group"}}
          ticket.sbrr_turned_on = true
          args = {:model_changes => {}, :options => {:action => "sbrr_turned_on_for_group"}}
          assign = sbrr_worker ticket, args
          assign.execute
        rescue Exception => e
          SBRR.log("Exception #{e.message} in sbrr turned on for group #{@group.id} ticket #{ticket.display_id} account #{Account.current.id}")
        end

        def sbrr_worker ticket, args
          SBRR::Execution.enqueue ticket, args
          #SBRR::Execution.new args
        end

        def user_toggle_synchronizers
          @group.available_agents.map do |user|
            SBRR::Synchronizer::UserUpdate::Toggle.new user, :group => @group
          end
        end

    end
  end
end
