module Widgets::FeedbackWidgetsHelper
	
	def widget_option type
		js_options[type]
	end


    def js_options 
    	{ :formTitle => params[:formTitle] || t('feedbackwidget_defaulttitle') }
    end
end