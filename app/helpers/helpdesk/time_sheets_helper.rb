module Helpdesk::TimeSheetsHelper
  def clear_view_timers(page, timeentry, timeentry_cleared)
    if !timeentry.nil? && !timeentry_cleared.nil? && (timeentry.ticket_id == timeentry_cleared.ticket_id)
      page.replace "timeentry_#{timeentry_cleared.id}", :partial => "/helpdesk/time_sheets/time_entry", :object => timeentry_cleared
    end
  end
  
  def renderTimesheetIntegratedApps( liquid_values ) 
    integrated_apps.map do |app|
      widget_code = get_app_widget_script(app[0], app[1], liquid_values)
      widget_code_with_ticket_id = Liquid::Template.parse(widget_code).render(liquid_values) 
      unless get_app_details(app[0]).blank?
         content_tag :fieldset, :class => "integration" do
           "<script type=\"text/javascript\">#{app[0]}inline=true;</script>"+
            widget_code_with_ticket_id + 
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
        page << "#{app[2]}.updateNotesAndTimeSpent('#{timeentry.note}' #{get_app_specific_hours(app[0], timeentry.hours, timeentry.timer_running)}, #{timeentry.billable});"
        page << "#{app[2]}.logTimeEntry();"
        page << "#{app[2]}.set_timesheet_entry_id(#{timeentry.id});" # This is not needed for update.  But no harm in calling.
      end
    end
  end
  
  def pushToIntegratedAppsWithoutLoading(timeentry, type=:edit)
    script = ""
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank? && timeentry.blank?
        integrated_app = timeentry.integrated_resources.find_by_installed_application_id(app_detail)
        unless integrated_app.blank?
          if type == :delete
            script += "#{app[2]}.deleteTimeEntryUsingIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});"
          else
            script += "#{app[2]}.updateTimeEntryUsingIds(#{integrated_app.remote_integratable_id} #{get_app_specific_hours(app[0], timeentry.hours, timeentry.timer_running)});"
          end
        end
      end
    end
    script
  end
  
  def modifyTimesheetApps(timeentry)
    script = ""
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank? && timeentry.blank?
        integrated_app = timeentry.integrated_resources.find_by_installed_application_id(app_detail)
        #script += "console.log('#{integrated_app.inspect}');"
        unless integrated_app.blank?
          script += "#{app[2]}.setIntegratedResourceIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});"
        end
      end
    end
    script
  end

  def get_app_specific_hours(app_name, hours, timer_running)
    hours = hours == 0 ? ", 0.01" : ", "+hours
    hours = ", ''" if app_name == "harvest" and timer_running
    hours
  end
  
  private 
    def integrated_apps 
      [["freshbooks", "freshbooks_timeentry_widget", "freshbooksWidget"],
       ["harvest",    "harvest_timeentry_widget",    "harvestWidget"]]
    end
end
