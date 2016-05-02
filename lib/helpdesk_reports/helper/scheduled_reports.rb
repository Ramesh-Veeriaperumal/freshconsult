module HelpdeskReports::Helper::ScheduledReports

  DESCRIPTION_MAX_LENGTH = 1_000_000
  SUBJECT_MAX_LENGTH = 400
  
  def delete_scheduled_report(report_filter)
    scheduled_report = report_filter.scheduled_task
    scheduled_report.destroy if scheduled_report
  end
  
  def save_scheduled_report report_filter
    if (report_filter.new_record? || !report_filter.scheduled_task)
      scheduled_task = build_scheduled_task(report_filter)
    else 
      scheduled_task = retrieve_scheduled_task(report_filter)
    end
    
    if(scheduled_task && scheduled_task.valid?)
      scheduled_task.save
      
      @data_map[:schedule_config] = schedule_config_json(report_filter)

      res = {status: 200, 
            id: report_filter.id,
            filter_name: @filter_name,
            data: @data_map,
      }
    else
      res = {status: 422, :errors => error_messages(report_filter.errors.messages.merge(scheduled_task.errors.messages)).join('. ')}
    end
  end
  
  def build_scheduled_task report_filter
    task_config = @schedule[:scheduled_task].symbolize_keys
    scheduled_task = report_filter.build_scheduled_task(
      frequency: task_config[:frequency].to_i,
      minute_of_day: task_config[:minute_of_day].to_i,
      day_of_frequency: task_config[:day_of_frequency].to_i,
      start_date: Time.now.utc,
      status: Helpdesk::ScheduledTask::STATUS_NAME_TO_TOKEN[:available]
    )
    
    build_schedule_configuration scheduled_task
    scheduled_task
  end
  
  def retrieve_scheduled_task report_filter
    task_config = @schedule[:scheduled_task].symbolize_keys
    scheduled_task = report_filter.scheduled_task
    status = scheduled_task.enqueued? ? scheduled_task.status : 0
    
    scheduled_task.assign_attributes(
      frequency: task_config[:frequency].to_i,
      minute_of_day: task_config[:minute_of_day].to_i,
      day_of_frequency: task_config[:day_of_frequency].to_i,
      # start_date: Date.today,
      # end_date: Date.today + 100.years,
      status: status
    )
    sch_config = scheduled_task.schedule_configurations.with_notification_type(:email_notification).first
    config_saved = sch_config ? update_schedule_configuration(scheduled_task) : build_schedule_configuration(scheduled_task)
    
    config_saved ? scheduled_task : false
  end
  
  def build_schedule_configuration scheduled_task
    desc = schedule_email_description
    scheduled_task.schedule_configurations.build(
      notification_type: Helpdesk::ScheduleConfiguration::NOTIFICATION_TYPE_TO_TOKEN[:email_notification],
      description: desc,
      config_data: schedule_config_params
    )
  end
  
  def update_schedule_configuration scheduled_task
    desc = schedule_email_description
    scheduled_task.schedule_configurations.with_notification_type(:email_notification).first.update_attributes(
      notification_type: Helpdesk::ScheduleConfiguration::NOTIFICATION_TYPE_TO_TOKEN[:email_notification],
      description: desc,
      config_data: schedule_config_params
    )
  end
  
  def schedule_config_params
    sch_config = @schedule[:schedule_configuration]['config'].symbolize_keys
    sub = sanitize_string(sch_config[:subject], SUBJECT_MAX_LENGTH)
    ids = sch_config[:emails].values.collect{|id| id.to_i}
    account_agent_ids = Account.current.agents_from_cache.collect { |au| au.user.id }
    existing_agents = ids & account_agent_ids
    {
      :emails => sch_config[:emails],
      :subject => sub,
      :agents_status => existing_agents
    }
  end

  def schedule_email_description
    sanitize_string(@schedule[:schedule_configuration]['config']['description'], DESCRIPTION_MAX_LENGTH)
  end
  
  def sanitize_string string , len
    string.length > len ? "#{string[0..len]}..." : string
  end
  
  def error_messages errors
    err = []
    err |= errors[:constraints] || []
    err |= errors[:"schedule_configurations.config_data"] || []
    err.push(I18n.t('helpdesk_reports.scheduled_reports.errors.general')) if err.blank?
    err
  end
  
end