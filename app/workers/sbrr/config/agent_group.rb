module SBRR
  module Config
    class AgentGroup < BaseWorker

      sidekiq_options queue:  :sbrr_config_agent_group,
                      retry: 0,
                      failures: :exhausted

      def perform args
        Thread.current[:sbrr_log] = [self.jid]
        args.symbolize_keys!
        @user  = Account.current.users.find_by_id args[:user_id]
        @group = Account.current.groups.find_by_id args[:group_id]
        @skills = Account.current.skills.where(id: args[:skill_ids]).to_a if args[:skill_ids] # agent destroy

        sbrr_user_config_synchronizer.sync args[:action].to_sym if @group.present? #group destroyed

        if (args[:action].to_sym == :create && @group.present? && @user.user_skills.present?)
          if (args[:multiple_agents_added_to_group])
            sbrr_resource_allocator_for_ticket_queue.allocate
          else
            sbrr_ticket_allotter_for_user.allot
          end
        end
      ensure
        Thread.current[:sbrr_log] = nil
      end

      private 

        def sbrr_user_config_synchronizer
          SBRR::Synchronizer::UserUpdate::Config.new @user, :group => @group, :skills => @skills
        end

        def sbrr_resource_allocator_for_ticket_queue
          SBRR::ResourceAllocator::TicketQueue.new(@user, :group => @group)
        end

        def sbrr_ticket_allotter_for_user
          SBRR::Allotter::Ticket.new(@user, @group)
        end

    end
  end
end
