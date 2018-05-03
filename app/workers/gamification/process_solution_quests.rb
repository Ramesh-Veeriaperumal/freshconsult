module Gamification
	class ProcessSolutionQuests < BaseWorker
		include Sidekiq::Worker
		sidekiq_options :queue => "gamification_solution_quests" , :retry => 0, :dead => true, :failures => :exhausted

		def perform(args)
			solution = Gamification::Quests::SolutionData.new(args)
			solution.evaluate_solution_quests
		rescue Exception => e
			puts "something is wrong: #{e.message}::#{e.backtrace.join("\n")}"
			NewRelic::Agent.notice_error(e, {:custom_params => {:description => "Error occoured while gamification process solution quest in sidekiq"}})
		end
	end
end
