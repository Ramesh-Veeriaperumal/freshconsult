class Helpdesk::NoteDrop < BaseDrop

	include ActionController::UrlWriter

	liquid_attributes << :private

	def initialize(source)
		super source
	end

	def id
		@source.display_id
	end

	def user
		@source.user
	end

	def description
	 	@source.body_html
	end

	def description_text
		@source.body
	end

	def created_on
	    @source.created_at
	end

	def survey_result
		@source.survey_remark.survey_result.rating unless @source.survey_remark.nil?
	end

	def attachments
	    @source.attachments
	end

	def dropboxes
		@source.dropboxes if @source.dropboxes.present?
	end

end