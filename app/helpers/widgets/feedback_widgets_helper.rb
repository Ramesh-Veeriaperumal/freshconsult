module Widgets::FeedbackWidgetsHelper

	def widget_option type
		js_options[type]
	end


    def js_options
    	{
          formTitle: (params[:formTitle] ? h(params[:formTitle]) : t('feedbackwidget_defaulttitle')).html_safe,
          submitTitle: (params[:submitTitle] ? h(params[:submitTitle]) : t('ticket.submit_feedback')).html_safe,
          screenshot: params[:screenshot].blank?,
          attachFile: params[:attachFile].blank?,
          searchArea: params[:searchArea].blank?,
          widgetView: params[:widgetView].blank?,
          formHeight: params[:formHeight],
          responsive: params[:responsive],
          widgetType: params[:widgetType]
    	}
    end
end
