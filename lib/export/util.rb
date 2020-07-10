module Export::Util
  include Rails.application.routes.url_helpers
  EXPORT_CLEANUP = "export_cleanup"
  def check_and_create_export type
    limit_data_exports type
    create_export type
  end

  def create_export type
    @data_export = Account.current.data_exports.new(
                                  :source => DataExport::EXPORT_TYPE[type.to_sym], 
                                  :user => User.current,
                                  :status => DataExport::EXPORT_STATUS[:started]
                                )
    @data_export.save
  end

  def limit_data_exports type
    acc_export = User.current.data_exports.safe_send("#{type.to_s}_export")
    acc_export.first.destroy if acc_export.count >= DataExport::TICKET_EXPORT_LIMIT
  end

  def build_file file_string, type, format = "csv"
    file_path = create_file(file_string, type, format)
    upload_file(file_path)
  end

  def create_file file_string, type, format = "csv"
    file_path = generate_file_path(type, format)
    write_file(file_string, file_path)
    file_path
  end
  
  def upload_file(file_path)
    @data_export.file_created!
    build_attachment(file_path)
    remove_export_file(file_path)
  end

  def write_file file_string, file_path
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def write_export_file(file_path)
    File.open(file_path, 'wb') do |f|
      yield(f)
    end
  end

  def write_csv(file, record)
    csv_string = CSVBridge.generate do |csv|
      csv << record
    end
    file.write(csv_string)
  end
  
  def append_file(file_string, file_path)
    File.open(file_path, "a") do |f|
      f.write(file_string)
    end
  end

  def generate_file_path type, format
    output_dir = "#{Rails.root}/tmp/export/#{Account.current.id}/#{type}" 
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{type.pluralize}-#{Time.now.strftime("%B-%d-%Y-%H:%M")}.#{format}"
    file_path
  end

  def build_attachment(file_path)
    file = File.open(file_path,  'r')
    attachment = @data_export.build_attachment(:content => file, :account_id => Account.current.id)
    attachment.save!
    @data_export.file_uploaded!
  end

  def remove_export_file(file_path)
    FileUtils.rm_f(file_path)
    @data_export.completed!
  end

  def hash_url portal_url
    Rails.application.routes.url_helpers.download_file_url(@data_export.source,
              file_hash(@data_export.id),
              host: portal_url, 
              protocol: Account.current.url_protocol
            )
  end

  def hash_url_with_token(portal_url, token)
    Rails.application.routes.url_helpers.download_file_url(@data_export.source,
                                                           token,
                                                           host: portal_url,
                                                           protocol: Account.current.url_protocol)
  end

  def file_hash(export_id)
    hash = Digest::SHA1.hexdigest("#{export_id}#{Time.now.to_f}")
    @data_export.save_hash!(hash)
    hash
  end

  def schedule_export_cleanup(export, type)
    job_id = [Account.current.id, 'export_cleanup', export.id].join('_')
    payload = {
      job_id: job_id,
      group: ::SchedulerClientKeys['export_group_name'],
      scheduled_time: (Time.zone.now + 15.days).utc.iso8601,
      data: {
        account_id: Account.current.id,
        export_id: export.id,
        enqueued_at: Time.now.to_i,
        scheduler_type: "#{type}_export_cleanup"
      },
      sqs: {
        url: AwsWrapper::SqsV2.queue_url(SQS[:fd_scheduler_export_cleanup_queue])
      }
    }
    scheduler_client = SchedulerService::Client.new(job_id: job_id,
                                                    payload: payload,
                                                    group: payload[:group],
                                                    account_id: payload[:data][:account_id],
                                                    end_point: ::SchedulerClientKeys['end_point'],
                                                    scheduler_type: payload[:data][:scheduler_type])
    response = scheduler_client.schedule_job
    Rails.logger.info "scheduler response message successful job_id:::: #{job_id} :::: #{response}"
    response
  end

  def parse_date(date_time)
    if date_time.class == String
      Time.zone.parse(date_time).strftime('%F %T')
    else
      date_time.strftime('%F %T')
    end
  end

  def escape_html(val)
    val.blank? || val.is_a?(Integer) ? val : CGI.unescapeHTML(val.to_s).gsub(/\s+/, ' ')
  end

  def set_current_user
    unless User.current
      user = Account.current.users.find(export_params[:current_user_id])
      user.make_current
    end
    TimeZone.set_time_zone
  end
end
