module Reports::TimesheetReportsHelper
	
	include Reports::GlanceReportsHelper

	def generate_pdf_action?
		params[:action] == "generate_pdf"
	end
end
