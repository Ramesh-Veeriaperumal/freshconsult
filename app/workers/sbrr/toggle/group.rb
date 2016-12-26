module SBRR
  module Toggle
    class Group < BaseWorker

      sidekiq_options :queue => :sbrr_group_toggle, 
                      :retry => 0, 
                      :backtrace => true, 
                      :failures => :exhausted

      def perform args
        @args  = args.symbolize_keys
        @group = Account.current.groups.find_by_id(@args[:group_id])
        if @args[:capping_limit_change].present?
          update_users_in_queues #user queues should be first
          trigger_assign_user_for_tickets_in_queue if @args[:capping_limit_change] == 'increased'
        else #turned on
          update_users_in_queues #user queues should be first
          enqueue_tickets_in_queues
        end
      end

      def update_users_in_queues
        user_toggle_synchronizers.each do |user_toggle_synchronizer|
          user_toggle_synchronizer.sync @group.skill_based_round_robin_enabled?
        end
      end

      def trigger_assign_user_for_tickets_in_queue #or should we do ticekt pull for agents?
        @group.ticket_queues.each do |queue|
          ticket_ids = queue.all
          Account.current.tickets.where(:display_id => ticket_ids).
            find_in_batches(:batch_size => ::Group::MAX_CAPPING_LIMIT) do |tickets|
              next if tickets.empty?
              is_assigned = {}
              tickets.all? do |ticket|
                is_assigned = SBRR::Assigner::User.new(ticket).assign
                ticket.save
                is_assigned[:can_assign] ? is_assigned[:do_assign] : true
              end
              break unless is_assigned
          end
        end
      end

      def enqueue_tickets_in_queues #later
        # status_ids   = Helpdesk::TicketStatus::sla_timer_on_status_ids(Account.current)
        # tickets = Sharding.run_on_slave{ @group.tickets.visible.sla_on_tickets(status_ids) } #find_each?
        # tickets.each do |ticket|
        #   ticket.sbrr_turned_on = true
        #   SBRR::Assignment.perform_async
        # end
      end

      private

        def user_toggle_synchronizers
          @group.available_agents.map do |user|
            SBRR::Synchronizer::UserUpdate::Toggle.new user, :group => @group
          end
        end

    end
  end
end
