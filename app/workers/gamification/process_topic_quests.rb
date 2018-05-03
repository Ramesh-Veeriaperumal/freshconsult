module Gamification
	class ProcessTopicQuests < BaseWorker
		include Sidekiq::Worker
		sidekiq_options :queue => "gamification_topic_quests" , :retry => 0, :dead => true, :failures => :exhausted

		def perform(args)
			topic = Gamification::Quests::TopicData.new(args)
			topic.evaluate_topic_quests()
		rescue Exception => e
			puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
			NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while gamification process topic quest in sidekiq"}})
		end

	end
end