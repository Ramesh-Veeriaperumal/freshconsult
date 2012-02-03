module Helpdesk::TimeSheetsHelper
  def clear_view_timers(page, timeentry, timeentry_cleared)
    if !timeentry.nil? && !timeentry_cleared.nil? && (timeentry.ticket_id == timeentry_cleared.ticket_id)
      page.replace "timeentry_#{timeentry_cleared.id}", :partial => "/helpdesk/time_sheets/time_entry", :object => timeentry_cleared
    end
  end
  
  def renderTimesheetIntegratedApps( liquid_values ) 
    integrated_apps.map do |app|
      unless get_app_details(app[0]).blank?
         content_tag :fieldset, :class => "integration" do
           "<script type=\"text/javascript\">#{app[0]}inline=true;</script>"+
           get_app_widget_script(app[0], app[1], liquid_values) +
           content_tag(:span, "", :class => "app-logo application-logo-#{app[0]}-small")      
           #Liquid::Template.parse(widget_include).render("ticket" => @ticket)
         end
      end
    end
  end
  
  def pushToTimesheetIntegratedApps(page, timeentry)
    integrated_apps.each do |app|
      unless get_app_details(app[0]).blank? 
        #page << "console.log(#{timeentry.to_json})"
        page << "#{app[2]}.updateNotesAndTimeSpent('#{timeentry.note}', #{get_time_in_hours(timeentry.time_spent)});"
        page << "#{app[2]}.logTimeEntry();"
        page << "#{app[2]}.set_timesheet_entry_id(#{timeentry.id});"
      end
    end
  end
  
  def modifyTimesheetApps( timeentry, type = :edit )
    script = ""
    integrated_apps.each do |app|
      unless get_app_details(app[0]).blank? && timeentry.blank?
        integrated_app = timeentry.integrated_resources.find_by_installed_application_id(get_app_details(app[0]))
        #script += "console.log('#{integrated_app.inspect}');"
        unless integrated_app.blank?
          case type
            when :delete then
              script += "#{app[2]}.deleteTimeEntryUsingIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});" 
            else
              script += "#{app[2]}.setIntegratedResourceIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});"
          end
        end
      end
    end
    script
  end
  
  private 
    def integrated_apps 
      [["freshbooks", "freshbooks_timeentry_widget", "freshbooksWidget"],
       ["harvest",    "harvest_timeentry_widget",    "harvestWidget"]]
    end
end
