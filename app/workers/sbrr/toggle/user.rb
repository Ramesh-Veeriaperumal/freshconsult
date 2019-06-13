module SBRR
  module Toggle
    class User < BaseWorker

      sidekiq_options queue: :sbrr_user_toggle,
                      retry: 0,
                      failures: :exhausted

      def perform args
        Thread.current[:sbrr_log] = [self.jid]
        @args = args.symbolize_keys
        @user = Account.current.users.find_by_id(@args[:user_id])
        handle_user_queues
        sbrr_ticket_allotter_for_user.allot if @user.agent.available
      ensure
        Thread.current[:sbrr_log] = nil
      end

      def handle_user_queues
        user_toggle_synchronizer.sync @user.agent.available
      end

      private

        def user_toggle_synchronizer
          SBRR::Synchronizer::UserUpdate::Toggle.new @user
        end

        def sbrr_ticket_allotter_for_user
          SBRR::Allotter::Ticket.new(@user)
        end
    end
  end
end
