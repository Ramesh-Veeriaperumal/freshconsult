class CustomSurvey::SurveyResultDrop < BaseDrop

	include Rails.application.routes.url_helpers

	def initialize(source)
    	super source
 	end

  	def name
  		@source.note_details[:survey]
  	end

  	def default_question
  		@source.ticket_info[:label]
  	end

  	def default_rating_class
  		CustomSurvey::Survey::CUSTOMER_RATINGS_STYLE[@source.ticket_info[:value]]
  	end

  	def default_rating_text
  		@source.ticket_info[:text]
  	end

  	def additional_questions
  		@source.additional_questions
  	end

end