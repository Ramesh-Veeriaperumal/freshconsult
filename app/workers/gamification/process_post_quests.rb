module Gamification
	class ProcessPostQuests < BaseWorker
		include Sidekiq::Worker
		sidekiq_options :queue => "gamification_post_quests" , :retry => 0, :dead => true, :failures => :exhausted

		def perform(args)
			post_quest = Gamification::Quests::PostData.new(args)
			post_quest.evaluate_post_quests
		rescue Exception => e
			puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
			NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while gamification process post quest in sidekiq"}})
		end

	end
end