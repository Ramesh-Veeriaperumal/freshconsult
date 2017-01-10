module SBRR
  module Toggle
    class User < BaseWorker

      sidekiq_options :queue => :sbrr_user_toggle, 
                      :retry => 0, 
                      :backtrace => true, 
                      :failures => :exhausted

      def perform args
        @args = args.symbolize_keys
        @user = Account.current.users.find_by_id(@args[:user_id])
        handle_user_queues
        handle_ticket_queues if @user.agent.available
      end

      def handle_user_queues
        user_toggle_synchronizer.sync @user.agent.available
      end

      def handle_ticket_queues
        @user.sbrr_fresh_user = true
        @user.groups.skill_based_round_robin_enabled.each do |group|
          assigned_tickets_count = @user.no_of_assigned_tickets(group)
          begin
            is_assigned = SBRR::Assigner::Ticket.new(nil, :user => @user, :group => group).assign
            assigned_tickets_count+=1 if is_assigned[:do_assign] #to avoid race - can remove after moving ticket_sync to callbacks
          end while is_assigned[:do_assign] && assigned_tickets_count < group.capping_limit
        end
      end

      private

        def user_toggle_synchronizer
          SBRR::Synchronizer::UserUpdate::Toggle.new @user
        end

    end
  end
end
