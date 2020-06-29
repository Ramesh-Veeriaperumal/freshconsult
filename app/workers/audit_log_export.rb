class AuditLogExport < BaseWorker
  include Redis::RedisKeys
  include Redis::OthersRedis
  include AuditLog::AuditLogHelper
  include AuditLog::SubscriptionHelper
  include AuditLog::AgentHelper
  include AuditLog::AutomationHelper
  include AuditLog::CannedResponseFolderHelper
  include AuditLog::CannedResponseHelper
  include AuditLog::CompanyHelper
  include AuditLog::SolutionCategoryHelper
  include AuditLog::SolutionFolderHelper
  include AuditLog::SolutionArticleHelper
  include Export::Util
  require 'json'
  require 'zip'
  require 'tempfile'
  require 'erb'
  sidekiq_options queue: :audit_log_export, retry: 5, failures: :exhausted

  def perform(args)
    @args = args.symbolize_keys!
    create_export 'audit_log'
    url = export_job_id_url
    response = HTTParty.get(url, basic_auth: basic_auth.symbolize_keys!).body
    response = JSON.parse(response).symbolize_keys
    if AuditLogConstants::WAITING_STATUSES.include? response[:status]
      if args[:time] <= 20
        time = args[:time] + 5
        self.class.perform_in(time.minutes, export_job_id: args[:export_job_id], archived: args[:archived],
                                            receive_via: args[:receive_via], format: args[:format], time: time, user_id: args[:user_id])
        return
      end
    elsif (AuditLogConstants::FAILURE_STATUSES.include? response[:status]) || args[:time] > 20
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
      DataExportMailer.send_email(:audit_log_export_failure, audit_log_failure_params[:user], audit_log_failure_params)
    end
    @data_export.save_hash!(args[:export_job_id])
    @export_file_path = fetch_export_file_path
    @file_size = read_hypertrail_json_file(response[:data]['export_url'])
    transfer_export_file
    FileUtils.rm_rf(dir_path)
  rescue StandardError => e
    @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
  end

  def basic_auth
    {
      username: HyperTrail::CONFIG['audit_log_file_export']['username'],
      password: HyperTrail::CONFIG['audit_log_file_export']['password']
    }
  end

  def export_job_id_url
    format((HyperTrail::CONFIG['audit_log_file_export']['api_endpoint']).to_s,
           account_id: Account.current.id, job_id: @args[:export_job_id])
  end

  def set_temp_file
    format(AuditLogConstants::TEMP_FILE, time: Time.zone.now.strftime('%Y-%m-%d'), id: Account.current.id)
  end

  def read_hypertrail_json_file(url)
    @filename = "tmp/#{@args[:export_job_id]}.tar.gz"
    File.open(@filename, 'wb') do |file|
      file.binmode
      HTTParty.get(url, stream_body: true) do |fragment|
        file.write(fragment)
      end
    end
    if @args[:archived] == AuditLogConstants::ARCHIVED[1]
      source_json_file = create_hypertrail_json_file
      return 0 if File.size(source_json_file).zero?
      @destination_file = @export_file_path
      safe_send("write_to_#{@args[:format]}", source_json_file)
    else
      format_dir_data
    end
  end

  def create_hypertrail_json_file
    system("tar -xf #{@filename} -C tmp/")
    open("tmp/#{@args[:export_job_id]}.json")
  end

  def create_hypertrail_json_dir
    @dir_name = FileUtils.mkdir_p "tmp/#{@args[:export_job_id]}"
    system("tar -xvzf #{@filename} -C #{@dir_name}")
  end

  def format_dir_data
    create_hypertrail_json_dir
    Dir.foreach(@dir_name.to_s) do |files|
      next if files == '.' || files == '..'

      source_file = File.open(Rails.root.join(@dir_name.to_s, files), 'r')
      if File.size(source_file) == 0 && Dir.glob(@dir_name.to_s + '/*').count == 1
        return 0
      elsif File.size(source_file) == 0
        next
      end
      json_file = File.basename(files, '.json')
      @destination_file = File.join(dir_path, %(#{json_file}.#{@args[:format]}))
      safe_send("write_to_#{@args[:format]}", source_file)
    end
  end

  def write_to_csv(file)
    write_headers_csv
    translate_json_file(file)
  end

  def write_to_xls(file)
    write_headers_xls
    translate_json_file(file)
    write_footer
  end

  def translate_json_file(file)
    file.each_line do |line|
      hash_line = JSON.parse(line).deep_symbolize_keys
      report_data = enrich_json_file(hash_line)
      format_file_data(report_data, @destination_file, @args[:format])
    end
  end

  def enrich_json_file(activity)
    *event_type, action = activity[:action].split('_')
    action = action.to_sym
    time = Time.zone.at(activity[:timestamp] / 1000)
    time = time.in_time_zone(User.current.time_zone)
    event_name = AuditLogConstants::EVENT_TYPES_NAME[event_type.join('_')] || :name
    report_data = {
      performer_id: activity[:actor][:id],
      performer_name: activity[:actor][:name],
      ip_address: activity[:ip_address],
      time: time.strftime('%b %d at %l:%M %p'),
      name: event_name_route(activity[:object][event_name], event_type, activity[:object], true)
    }
    report_data[:name][:name] = 'Personal' if report_data[:name][:name] == "Personal_#{Account.current.id}"
    assign_solution_attributes(report_data, activity) if solution_event?(event_type)
    report_data.merge! event_type_and_description(activity, action, event_type)
    report_data
  end

  def transfer_export_file
    if @file_size && @file_size.is_a?(Integer) && @file_size.zero?
      @data_export.no_logs!
      DataExportMailer.send_email(:no_logs, audit_log_failure_params[:user], audit_log_failure_params) if @args[:receive_via] == AuditLogConstants::RECEIVE_VIA[0]
    else
      write_to_s3
    end
  end

  def fetch_export_file_path
    temp_file = set_temp_file
    if @args[:archived] == AuditLogConstants::ARCHIVED[1]
      File.join(dir_path, %(#{temp_file}.#{@args[:format]}))
    end
  end

  def write_headers_csv
    CSV.open(@destination_file, 'wb') do |csv|
      csv << AuditLogConstants::COLUMN_HEADER
    end
  end

  def write_headers_xls
    @headers = AuditLogConstants::COLUMN_HEADER
    write_xls(@destination_file, xls_erb('header'), @headers)
  end

  def write_footer
    write_xls(@destination_file, xls_erb('footer'))
  end

  def write_to_s3
    write_options = if @args[:archived] == AuditLogConstants::ARCHIVED[1]
                      attachment_file_path = "audit_log/#{Account.current.id}"
                      @args[:format] == AuditLogConstants::FORMAT[0] ? { content_type: 'text/csv' } : { content_type: 'application/vnd.ms-excel' }
                    else
                      attachment_file_path = Rails.root.join('tmp', "#{Account.current.id}.zip").to_path
                      { content_type: 'application/octet-stream' }
                    end
    file = @export_file_path.present? ? File.open(@export_file_path) : File.open(write_to_zip_file(attachment_file_path), 'r')
    AwsWrapper::S3Object.store(attachment_file_path, file, S3_CONFIG[:bucket], write_options)
    @args[:archived] == AuditLogConstants::ARCHIVED[1] ? upload_file(@export_file_path) : upload_file(attachment_file_path)
    hash_file_name = @args[:export_job_id]
    @data_export.save_hash!(hash_file_name)
    url = Rails.application.routes.url_helpers.download_file_url(@data_export.source, hash_file_name,
                                                                 host: Account.current.host,
                                                                 protocol: 'https')
    DataExportMailer.send_email(:audit_log_export, audit_log_email_params(url)[:user], audit_log_email_params(url)) if @args[:receive_via] == AuditLogConstants::RECEIVE_VIA[0]
  end

  def write_to_zip_file(zip_file_path)
    Zip::File.open(zip_file_path, Zip::File::CREATE) do |zipfile|
      file_list = Dir.glob(dir_path.to_s + '/*')
      file_list.each do |file|
        zipfile.add(File.basename(file), file)
      end
    end
    zip_file_path
  end

  def dir_path
    FileUtils.mkdir_p(AuditLogConstants::EXPORT_FILE_PATH)
  end

  def audit_log_email_params(url)
    @audit_log_email_params ||= {
      user: User.current,
      domain: Account.current.full_domain,
      url: url,
      email: User.current.try(:email),
      type: 'audit_log'
    }
  end

  def audit_log_failure_params
    @audit_log_failure_params ||= {
      user: User.current,
      domain: Account.current.full_domain,
      email: User.current.try(:email),
      type: 'audit_log'
    }
  end
end
