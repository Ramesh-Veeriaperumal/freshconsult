module Mobile::Actions::Freshfone

	CALL_JSON_OPTIONS = {:except => [], :methods => [:location, :caller_number], :include => {:agent => {:only=>[:id], :methods => [:name, :user_avatar]}, :customer => {:only => [:name]} , :ticket => {:only => [:display_id, :status, :subject, :priority], :methods => [:status_name]}}}
	NUMBER_JSON_OPTIONS = {:only => [:id, :number, :display_number]}

	def as_calls_mjson
		as_json(CALL_JSON_OPTIONS)
	end


	def as_numbers_mjson
		as_json(NUMBER_JSON_OPTIONS)
	end
end
