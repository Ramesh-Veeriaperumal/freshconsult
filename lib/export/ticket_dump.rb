class Export::TicketDump < Export::TicketSchedule
  
  def perform
    initialize_params
    @file_path = generate_file_path('ticket', 'csv')
    Sharding.run_on_slave { export_tickets }
    upload_file
    save_file_name file_name
    DataExportMailer.send(
      @no_tickets ? :scheduled_ticket_export_no_data : :scheduled_ticket_export,
      :filter_id => @schedule.id) if @schedule.send_email?
    destroy_task
  rescue => e
    NewRelic::Agent.notice_error(e,{:description => "Ticket Schedule Dump error #{Account.current.id} :: #{export_params[:task_id]}"})
    Rails.logger.debug "Ticket Schedule Dump error ::#{e.message}\n#{e.backtrace.join("\n")}"
  end

  protected

    def initialize_params
      @task = Account.current.scheduled_tasks.find_by_id(export_params[:task_id])
      @schedule = Account.current.scheduled_ticket_exports_from_cache
                  .find{ |f| f.id == @task.schedulable_id}
      super
    end

    def filter_conditions_hash
      @schedule.custom_filter_data.to_json
    end

    def all_export_fields
      {
        :export_fields => @schedule.fields_data["ticket"] || {},
        :contact_fields => @schedule.fields_data["contact"] || {},
        :company_fields => @schedule.fields_data["company"] || {}
      }
    end

    def start_date
      initial_dump ? Time.zone.now.beginning_of_month.utc.to_s : super
    end

    def initial_dump
      @schedule.initial_export.to_s.to_bool
    end

    def upload_file
      file = File.open(@file_path)
      AwsWrapper::S3Object.store(s3_file_path, file, S3_CONFIG[:bucket])
    end

    def s3_file_path
      @s3_file_path ||=
        ScheduledTicketExport::S3_TICKETS_PATH % { :schedule_id => @schedule.id,
                                                    :filename => file_name}
    end

    def file_name
      @file_name ||= @schedule.file_name(Time.zone.now.to_s)
    end

    def save_file_name file_name
      @schedule.update_column(:latest_file, file_name)
    end

    def destroy_task
      @task.destroy
      FileUtils.rm_f(@file_path)
    end

end