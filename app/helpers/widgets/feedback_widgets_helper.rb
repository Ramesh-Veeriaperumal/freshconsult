module Widgets::FeedbackWidgetsHelper

	def widget_option type
		js_options[type]
	end


    def js_options
    	{
    		:formTitle => (params[:formTitle] ? h(params[:formTitle]) : t('feedbackwidget_defaulttitle')).html_safe,
    		:screenshot => params[:screenshot].blank?,
            :screenr_recording => params[:screenr_recording].blank?,
    		:attachFile => params[:attachFile].blank?,
    		:searchArea => params[:searchArea].blank?,
            :widgetView => params[:widgetView].blank?,
            :formHeight => params[:formHeight],
            :responsive => params[:responsive],
            :widgetType => params[:widgetType],
						:captcha => params[:captcha]
    	}
    end
end
