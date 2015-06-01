module Helpdesk::TimeSheetsHelper
  def clear_view_timers(page, timeentry, timeentry_cleared)
    if !timeentry.nil? && !timeentry_cleared.nil? && (timeentry.workable.eql?(timeentry_cleared.workable))
      page.replace "timeentry_#{timeentry_cleared.id}", :partial => "time_entry", :object => timeentry_cleared
    end
  end
  
  def renderTimesheetIntegratedApps( liquid_values ) 
    integrated_apps.map do |app|
      widget_code = get_app_widget_script(app[0], app[1], liquid_values)
      widget_code_with_ticket_id = Liquid::Template.parse(widget_code).render(liquid_values, :filters => [Integrations::FDTextFilter])
      unless get_app_details(app[0]).blank?
         content_tag :fieldset, :class => "integration still_loading #{app[0]}_timetracking_widget" do
           ("<script type=\"text/javascript\">#{app[0]}inline=true;</script>"+
            '<div class="integration_container">' + widget_code_with_ticket_id + '</div>' +
           content_tag(:span, check_box_tag("#{app[0]}-timeentry-enabled", "1", :checked => 'checked'), :class => "app-logo application-logo-#{app[0]}-small") ).html_safe     
           #Liquid::Template.parse(widget_include).render("ticket" => @ticket)
         end
      end
    end
  end
  
  def pushToTimesheetIntegratedApps(page, timeentry)
    integrated_apps.each do |app|
      unless get_app_details(app[0]).blank? 
        page << "try{"
        page << "if (jQuery('##{app[0]}-timeentry-enabled').is(':checked')) {"
        page << "#{app[2]}.updateNotesAndTimeSpent(#{timeentry.note.to_json}, #{timeentry.time_spent == 0? "0.01" : timeentry.hours}, #{timeentry.billable}, #{timeentry.executed_at.to_json});"
        page << "#{app[2]}.createTimeEntry(#{timeentry.id});"
        page << "}"
        page << "}catch(e){ log(e)}"
      end
    end
  end


  def updateToTimesheetIntegratedApps(page, timeentry, type = :create)
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank? or timeentry.blank?
        page << "try{"
        page << "if (jQuery('##{app[0]}-timeentry-enabled').is(':checked')) {"
        page << "#{app[2]}.updateNotesAndTimeSpent(#{timeentry.note.to_json}, #{timeentry.time_spent == 0? "0.01" : timeentry.hours}, #{timeentry.billable}, #{timeentry.executed_at.to_json});"
        page << "#{app[2]}.logTimeEntry(#{timeentry.id});"
        page << "}"
        page << "}catch(e){ log(e)}"
      end
    end
  end
  
  def pushToIntegratedAppsWithoutLoading(timeentry, type=:edit)
    script = ""
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank? or timeentry.blank?
        integrated_app = timeentry.integrated_resources.find_by_installed_application_id(app_detail)
        unless integrated_app.blank?
          if type == :delete
            script += "#{app[2]}.deleteTimeEntryUsingIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});"
          else
            script += "#{app[2]}.updateTimeEntryUsingIds(#{integrated_app.remote_integratable_id}, #{timeentry.time_spent == 0? "0.01" : timeentry.hours});"
          end
        end
      end
    end
    script
  end
  
  def modifyTimesheetApps(timeentry)
    script = ""
    script += %Q|jQuery("#timeentry_apps_add").detach().appendTo("#edit_timeentry_#{timeentry.id} .edit_timesheet").show();|
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank? or timeentry.blank?
        integrated_app = timeentry.integrated_resources.find_by_installed_application_id(app_detail)
        #script += "console.log('#{integrated_app.inspect}');"
        if integrated_app.blank?
          script += "#{app[2]}.resetIntegratedResourceIds();"
        else

          script += "#{app[2]}.resetIntegratedResourceIds(#{integrated_app.id}, #{integrated_app.remote_integratable_id});"
        end
      end
    end
    html_safe(script)
  end

  def agent_list
    privilege?(:edit_time_entries) ?
      current_account.users.technicians.visible : [current_user]
  end

  def timesheet_integrations_enabled?
    integrated_apps.each do |app|
      app_detail = get_app_details(app[0])
      unless app_detail.blank?
        return true
      end
    end

    return false
  end
  
  def ticket_tasks_field(form, agent_list, type)
    %(
      <dt>#{form.label :user_id, t('.agent')} </label></dt> 
       <dd>
        #{form.collection_select( :user_id, agent_list, :id, :name, {:selected => form.object.nil? ? current_user.id : form.object.user_id}, {:class => "select2"})}
      </dd>
      ).html_safe  
  end

  def time_entry_note note
    note.gsub(/(\r\n|\n|\r)/, '<br />').html_safe
  end
  
  private 
    def integrated_apps 
      [
        [Integrations::Constants::APP_NAMES[:freshbooks],   "#{Integrations::Constants::APP_NAMES[:freshbooks]}_timeentry_widget",   "freshbooksWidget"],
        [Integrations::Constants::APP_NAMES[:harvest],      "#{Integrations::Constants::APP_NAMES[:harvest]}_timeentry_widget",      "harvestWidget"],
        [Integrations::Constants::APP_NAMES[:workflow_max], "#{Integrations::Constants::APP_NAMES[:workflow_max]}_timeentry_widget", "workflowMaxWidget"],
        [Integrations::Constants::APP_NAMES[:quickbooks], "#{Integrations::Constants::APP_NAMES[:quickbooks]}_timeentry_widget", "quickbooksWidget"]
      ]
    end
end
