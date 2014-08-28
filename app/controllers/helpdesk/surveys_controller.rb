class Helpdesk::SurveysController < ApplicationController

	before_filter :check_feature?, :load_ticket

	def index
		survey_results = @ticket.survey_results
		respond_to do |format|
			format.json do 
				render :json => survey_results
			end
			format.xml do 
				render :xml => survey_results.to_xml(:except=>[:account_id])
			end
		end
	end

	def rate
		@survey_result = @ticket.survey_results.create({        
			:survey_id => current_account.survey.id,                
			:customer_id => @ticket.requester_id,
			:agent_id => @ticket.responder_id,
			:group_id => @ticket.group_id,                
			:rating => params[:rating]
			})

		@survey_result.add_feedback(params[:feedback]) unless params[:feedback].blank?
		respond_to do |format|
			format.json do 
				render :json =>@survey_result
			end
			format.xml do 
				render :xml =>@survey_result.to_xml(:except=>[:account_id])
			end
		end
	end

	private 

		def load_ticket
			@ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
			raise ActiveRecord::RecordNotFound if @ticket.nil?
		end

		def check_feature?
			handle_error(StandardError.new(t('non_covered_feature_error'))) unless current_account.features?(:surveys,:survey_links)
		end
end