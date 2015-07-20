class Helpdesk::SurveysController < ApplicationController

	before_filter :check_feature?, :load_ticket
	before_filter :check_rating?, only: [:rate]

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
		@survey_result = (current_account.custom_survey_enabled) ? create_custom_survey_result : create_classic_survey_result
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
	
		# For backward compatibility purpose, old rating has been mapped with custom equivalent
		def custom_rating rating			
			classic_vs_custom = {
					"#{Survey::HAPPY}" => CustomSurvey::Survey::EXTREMELY_HAPPY,
					"#{Survey::NEUTRAL}" => CustomSurvey::Survey::NEUTRAL,
					"#{Survey::UNHAPPY}" => CustomSurvey::Survey::EXTREMELY_UNHAPPY
			}
			if (rating.to_i<100 && rating.to_i>0)
					rating = classic_vs_custom[rating]
			end

			rating
			
		end
		
		def create_classic_survey_result
			survey_result = @ticket.survey_results.create({        
				:survey_id => current_account.survey.id,                
				:customer_id => @ticket.requester_id,
				:agent_id => @ticket.responder_id,
				:group_id => @ticket.group_id,                
				:rating => params[:rating]
			})
			survey_result.add_feedback(params[:feedback]) unless params[:feedback].blank?
			survey_result
		end
		
		def create_custom_survey_result
			rating = custom_rating(params[:rating])
			old_rating = CustomSurvey::Survey::old_rating rating.to_i
			survey = current_account.survey
			survey_result = @ticket.custom_survey_results.create({
						      :account_id => survey.account_id,
						      :survey_id => survey.id,
						      :customer_id => @ticket.requester_id,
						      :agent_id => @ticket.responder_id,
						      :group_id => @ticket.group_id,
						      :custom_field => {"#{survey.default_question.name}" => rating},
						      :rating => old_rating
						    })
			survey_result.add_feedback(params) unless params[:feedback].blank?
			survey_result
		end

		def load_ticket
			@ticket = current_account.tickets.find_by_display_id(params[:ticket_id])
			raise ActiveRecord::RecordNotFound if @ticket.nil?
		end
		
		def check_rating?
			allowed_ratings = Survey::CUSTOMER_RATINGS.collect{|c| c[0]}
			allowed_ratings = allowed_ratings + current_account.survey.choice_names.collect{|c|c[0]} if current_account.custom_survey_enabled
			handle_error(StandardError.new(t('helpdesk.surveys.invalid_rating',{:rating => params[:rating]}))) unless allowed_ratings.include? params[:rating].to_i
		end

		def check_feature?
			handle_error(StandardError.new(t('non_covered_feature_error'))) unless current_account.features?(:surveys,:survey_links)
		end
end