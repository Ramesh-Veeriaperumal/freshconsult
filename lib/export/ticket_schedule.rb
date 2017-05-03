class Export::TicketSchedule < Export::Ticket

  ALL_FIELDS = [:export_fields, :contact_fields, :company_fields]

  def perform
    initialize_params
    file_string =  Sharding.run_on_slave{ export_file }
    file_path = create_file(file_string, "ticket")
    ScheduledTaskMailer.email_scheduled_report({ :file_path => file_path }, @task)
  rescue => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.debug "Ticket Schedule Export error ::#{e.message}\n#{e.backtrace.join("\n")} "
  end
  
  protected

  def initialize_params
    @task = Account.current.scheduled_tasks.find_by_id(export_params[:task_id])
    @config = @task.schedule_configurations.first
    export_params.merge!({ 
      :format => "csv",
      :ticket_state_filter => "updated_at",
      :data_hash => filter_conditions_hash,
      :current_user_id => @task.user_id
    }).merge!(all_export_fields)
    set_current_user
    export_params.merge!(date_range)
    super
  end

  def start_date
    case @task.frequency_name
    when :daily
      (Time.zone.now.beginning_of_hour - 1.day).utc.to_s
    when :weekly
      (Time.zone.now.beginning_of_hour - 1.week).utc.to_s
    when :hourly
      (Time.zone.now.beginning_of_hour - 1.hour).utc.to_s
    else
      (Time.zone.now.beginning_of_hour - 1.day).utc.to_s
    end
  end

  def filter_conditions_hash
    @task.schedulable.data[:data_hash].select{|t| t["condition"] != "created_at"}.to_json
  end

  def all_export_fields
    ALL_FIELDS.map{|f| [f, {}]}.to_h.merge(@config.config_data[:fields])
  end

  def date_range
    {
      :start_date => start_date,
      :end_date => Time.zone.now.beginning_of_hour.utc.to_s
    }
  end

  def date_conditions
    %(and helpdesk_tickets.#{export_params[:ticket_state_filter]} 
       between '#{export_params[:start_date]}' and '#{export_params[:end_date]}'
      )
  end

end