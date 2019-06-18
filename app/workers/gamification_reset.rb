class GamificationReset < BaseWorker

  sidekiq_options :queue => :reset_gamification_score, :retry => 0, :failures => :exhausted

  def perform(args={})
  	Thread.current[:gamification_reset] = true
  	begin
	    args["agent_id"].nil? ? reset_all_agents_score : reset_agent_score(args["agent_id"])
	  ensure
	  	Thread.current[:gamification_reset] = nil
	  end	
  end

  private

  def reset_agent_score(id)
    agent = Account.current.agents.find_by_id(id)
    agent.reset_gamification if agent
  end

  def reset_all_agents_score
    Account.current.agents.find_in_batches(:batch_size => 300) do |batch|
      batch.each do |agent|
        agent.reset_gamification
      end
    end
  end

end