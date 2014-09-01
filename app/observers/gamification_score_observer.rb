class GamificationScoreObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, SurveyResult

	include Gamification::GamificationUtil

	def after_commit_on_create(model)
		return unless gamification_feature?(model.account)
		model_name = (:"Helpdesk::Ticket".eql? model.class.name.to_sym) ? "ticket" : model.class.name.downcase
		send("process_#{model_name}_score",model)
	end

	def after_commit_on_update(model)
		return unless (!(:SurveyResult.eql? model.class.name.to_sym) and gamification_feature?(model.account))
		process_ticket_score_on_update(model)
	end

	private

	def process_ticket_score(ticket)
		add_support_score(ticket) unless ticket.active?
	end

	def process_surveyresult_score(sr)
		SupportScore.add_happy_customer(sr.surveyable) if sr.happy?
    SupportScore.add_unhappy_customer(sr.surveyable) if sr.unhappy?
	end

	def process_ticket_score_on_update(ticket)
		if (ticket.reopened_now? or (ticket.ticket_changes.key?(:deleted) && ticket.deleted?))
        Resque.enqueue(Gamification::Scoreboard::ProcessTicketScore, { :id => ticket.id, 
                :account_id => ticket.account_id, :remove_score => true })
    elsif ticket.resolved_now?
      add_support_score(ticket)
    end
	end

	def add_support_score(ticket)
		Resque.enqueue(Gamification::Scoreboard::ProcessTicketScore, { :id => ticket.id, 
                :account_id => ticket.account_id,
                :fcr =>  ticket.first_call_resolution?,
                :resolved_at_time => ticket.resolved_at,
                :remove_score => false }) unless (ticket.resolved_at.nil? or ticket.responder.nil?)
	end

end