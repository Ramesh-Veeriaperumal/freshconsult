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

        # check if the agent has write access group then sync
        # remove agent from queue if the group is converted from write to read
        # add agent to queue if the group is converted from read to write
        if Account.current.advanced_ticket_scopes_enabled? && [:create, :update].include?(args[:action].to_sym)
          ssbr_user_action = action_to_be_performed(args[:action].to_sym, args[:write_access_agent], args[:write_access_changes])
          sbrr_user_config_synchronizer.sync ssbr_user_action if ssbr_user_action
        elsif @group.present?
          sbrr_user_config_synchronizer.sync args[:action].to_sym # group destroyed
        end

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

        def action_to_be_performed(action, write_access_agent, write_access_changes)
          if write_access_agent
            action
          elsif write_access_changed_to_read_access?(action, write_access_changes)
            :destroy
          end
        end

        def sbrr_user_config_synchronizer
          SBRR::Synchronizer::UserUpdate::Config.new @user, :group => @group, :skills => @skills
        end

        def sbrr_resource_allocator_for_ticket_queue
          SBRR::ResourceAllocator::TicketQueue.new(@user, :group => @group)
        end

        def sbrr_ticket_allotter_for_user
          SBRR::Allotter::Ticket.new(@user, @group)
        end

        def write_access_changed_to_read_access?(action, write_access_changes)
          action == :update && write_access_changes && write_access_changes[0]
        end
    end
  end
end
