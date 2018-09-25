class GamificationScoreObserver < ActiveRecord::Observer

	observe Helpdesk::Ticket, SurveyResult, CustomSurvey::SurveyResult

	include Gamification::GamificationUtil
	include Redis::RedisKeys
	include Redis::OthersRedis
  
  def after_commit(model)
    if model.safe_send(:transaction_include_action?, :create)
      commit_on_create(model)
    elsif model.safe_send(:transaction_include_action?, :update)
      commit_on_update(model)
    end
    true
  end
  
  private
  
	def commit_on_create(model)
		return unless gamification_feature?(model.account)
		safe_send("process_#{model_name(model)}_score",model)
	end
	
	def commit_on_update(model)
		return unless (!([:SurveyResult,:"CustomSurvey::SurveyResult"].include? model.class.name.to_sym) and gamification_feature?(model.account))
		process_ticket_score_on_update(model)
	end

	def process_ticket_score(ticket)
		add_support_score(ticket) unless (ticket.active? and !ticket.outbound_email?)
	end

	def process_surveyresult_score(sr)
		SupportScore.add_happy_customer(sr.surveyable) if sr.happy?
		SupportScore.add_unhappy_customer(sr.surveyable) if sr.unhappy?
	end

	def process_ticket_score_on_update(ticket)
		if (ticket.reopened_now? or (ticket.ticket_changes.key?(:deleted) && ticket.deleted?))
			args = { :id => ticket.id, :account_id => ticket.account_id, :remove_score => true }
			Gamification::ProcessTicketScore.perform_async(args)
    elsif ticket.resolved_now?
      		add_support_score(ticket)
    end
	end

	def add_support_score(ticket)
		args = { :id => ticket.id, :account_id => ticket.account_id, :fcr =>  ticket.first_call_resolution?, :resolved_at_time => ticket.resolved_at, :remove_score => false }
		Gamification::ProcessTicketScore.perform_async(args) unless (ticket.resolved_at.nil? or ticket.responder.nil?)
	end

  private 

	def model_name(name)
		case name.class.name.to_sym
		when :"Helpdesk::Ticket"
			return "ticket"
		when :"CustomSurvey::SurveyResult"
			return "surveyresult"
    else
      return name.class.name.downcase
    end
	end

end
