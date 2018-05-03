module Gamification
  class UpdateUserScore < BaseWorker
    include Sidekiq::Worker
    sidekiq_options :queue => "gamification_user_score" , :retry => 0, :dead => true, :failures => :exhausted

    def perform(args)
      Gamification::Scoreboard::UserData.new(args).update_score
    rescue Exception => e
      puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while gamification update user score in sidekiq"}})
    end
    
  end
end