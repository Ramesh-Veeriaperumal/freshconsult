module Helpdesk::TimeSheetsHelper
  def clear_view_timers(page, timeentry, timeentry_cleared)
    if !timeentry.nil? && (timeentry.ticket_id == timeentry_cleared.ticket_id)
      page.replace "timeentry_#{timeentry_cleared.id}", :partial => "/helpdesk/time_sheets/time_entry", :object => timeentry_cleared
    end
  end
  
  def renderTimesheetIntegratedApps( liquid_values, action_type = :new, inline = true )
    apps = [["freshbooks", "freshbooks_timeentry_widget", "freshbooksWidget"],
            ["harvest",    "harvest_timeentry_widget", "harvestWidget"]]
      
    apps.map do |app|
      unless get_app_details(app[0]).blank?
        case action_type
          when :new then
            constructTimeWidget app[0], liquid_values 
          when :create then
            
        end
      end
    end
  end
  
  def constructTimeWidget name, liquid_values
    content_tag :fieldset, :class => "integration" do
      get_app_widget_script("freshbooks", "freshbooks_timeentry_widget", liquid_values) +
      content_tag(:span, "", :class => "app-logo application-logo-#{name}-small")      
      #Liquid::Template.parse(widget_include).render("ticket" => @ticket)
    end
  end
end
