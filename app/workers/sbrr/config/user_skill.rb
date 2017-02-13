module SBRR
  module Config
    class UserSkill < BaseWorker

      sidekiq_options :queue => :sbrr_config_user_skill, 
                      :retry => 0, 
                      :backtrace => true, 
                      :failures => :exhausted

      def perform args
        args.symbolize_keys!
        @user  = Account.current.users.find_by_id args[:user_id]
        @skill = Account.current.skills.find_by_id args[:skill_id]
        sbrr_user_config_synchronizer.sync args[:action].to_sym if @skill.present? #skill destroyed
      end

      private 
        
        def sbrr_user_config_synchronizer
          SBRR::Synchronizer::UserUpdate::Config.new @user, :skill => @skill
        end

    end
  end
end
