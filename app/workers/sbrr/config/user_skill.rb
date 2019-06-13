module SBRR
  module Config
    class UserSkill < BaseWorker

      sidekiq_options queue: :sbrr_config_user_skill,
                      retry: 0,
                      failures: :exhausted

      def perform args
        begin
          Thread.current[:sbrr_log] = [self.jid]
          args.symbolize_keys!
          user  = Account.current.users.find_by_id args[:user_id]
          skill = Account.current.skills.find_by_id args[:skill_id]
          args[:action] = args[:action].to_sym
          sbrr_user_config_synchronizer(user, skill).sync args[:action] if skill.present? #skill destroyed
          is_agent_available = user.agent.try(:available) # agent will be nil on agent delete
          SBRR.log "[SBRR::Config::UserSkill] action: #{args[:action]}, 
            user_id: #{args[:user_id]}, is_available: #{is_agent_available}, 
            skill_id: #{args[:skill_id]}}"
          if args[:action] == :create and is_agent_available
            if args[:multiple_skills_added_to_user]
              sbrr_ticket_allotter_for_user(user).allot
            else #multiple agents added to a skill scenario
              sbrr_resource_allocator_for_ticket_queue(user, skill).allocate
            end
          end
        rescue => e
          SBRR.log "[SBRR::Config::UserSkill] Perform args: #{args.inspect}, #{e.backtrace}"
          raise e
        ensure
          Thread.current[:sbrr_log] = nil
        end
      end

      private 
        
        def sbrr_user_config_synchronizer(user, skill)
          SBRR::Synchronizer::UserUpdate::Config.new user, :skill => skill
        end

        def sbrr_resource_allocator_for_ticket_queue(user, skill)
          SBRR::ResourceAllocator::TicketQueue.new(user, :skill => skill)
        end

        def sbrr_ticket_allotter_for_user(user)
          SBRR::Allotter::Ticket.new(user)
        end
    end
  end
end
