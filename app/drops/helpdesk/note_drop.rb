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

end