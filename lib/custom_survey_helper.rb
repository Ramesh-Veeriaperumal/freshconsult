module CustomSurveyHelper

  def self.render_content_for_placeholder(locals)
    action_view = ActionView::Base.new(Rails.configuration.paths["app/views"])
    action_view.class_eval do 
      include Rails.application.routes.url_helpers
      include Helpdesk::TicketNotifierHelper
    end
    action_view.render( :partial => "helpdesk/ticket_notifier/custom_survey",
                        :locals => locals)
  end
end
