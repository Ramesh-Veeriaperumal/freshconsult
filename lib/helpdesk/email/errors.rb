module Helpdesk
	module Email
		module Errors
			class EmailDBSaveError < StandardError
			end

			class EmailDBFetchError < StandardError
			end

			class EmailDBDeleteError < StandardError
			end

			class EmailDBError < StandardError
			end

			class EmailDBRecordNotFound < StandardError
			end
		end
	end
end
