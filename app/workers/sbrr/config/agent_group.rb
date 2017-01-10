module SBRR
  module Config
    class AgentGroup < BaseWorker

      sidekiq_options :queue => :sbrr_config_agent_group, 
                      :retry => 0, 
                      :backtrace => true, 
                      :failures => :exhausted

      def perform args
        args.symbolize_keys!
        @user  = Account.current.users.find_by_id args[:user_id]
        @group = Account.current.groups.find_by_id args[:group_id]
        @skills = Account.current.skills.find_all_by_id args[:skill_ids] if args[:skill_ids] #agent destroy
        sbrr_user_config_synchronizer.sync args[:action].to_sym if @group.present? #group destroyed
      end

      private 
        
        def sbrr_user_config_synchronizer
          SBRR::Synchronizer::UserUpdate::Config.new @user, :group => @group, :skills => @skills
        end

    end
  end
end
