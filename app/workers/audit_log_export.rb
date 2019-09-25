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
  include Export::Util
  require 'json'
  require 'zip'
  require 'tempfile'
  sidekiq_options queue: :audit_log_export, retry: 5,  failures: :exhausted

  def perform(args)
    args.symbolize_keys!
    set_current_user(args[:user_id])
    create_export 'audit_log'
    url = export_job_id_url(args[:export_job_id])
    response = HTTParty.get(url, basic_auth: basic_auth.symbolize_keys!).body
    response = JSON.parse(response).symbolize_keys
    if AuditLogConstants::WAITING_STATUSES.include? response[:status]
      if args[:time] <= 20
        time = args[:time] + 5
        self.class.perform_in(time.minutes, export_job_id: args[:job_id], basic_auth: args[:basic_auth],
                                            time: time, user_id: args[:user_id])
        return
      end
    elsif (AuditLogConstants::FAILURE_STATUSES.include? response[:status]) || args[:time] > 20
      @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
      DataExportMailer.send_email(:audit_log_export_failure, audit_log_failure_params[:user], audit_log_failure_params)
    end
    temp_file = set_temp_file
    csv_file = File.join(FileUtils.mkdir_p(AuditLogConstants::CSV_FILE), %(#{temp_file}.csv))
    res = translate_json_file(csv_file, response[:data]['export_url'], args[:export_job_id])
    @data_export.save_hash!(args[:export_job_id])
    if res == 0
      @data_export.no_logs!
      DataExportMailer.send_email(:no_logs, audit_log_failure_params[:user], audit_log_failure_params) if args[:receive_via] == AuditLogConstants::RECEIVE_VIA[0]
    else
      write_to_s3(csv_file, args[:receive_via], args[:export_job_id])
    end
  rescue Exception => e
    @data_export.failure!(e.message + "\n" + e.backtrace.join("\n"))
  end

  def set_current_user(user_id)
    unless User.current
      user = Account.current.users.find(user_id)
      user.make_current
    end
  end

  def basic_auth
    {
      username: HyperTrail::CONFIG['audit_log_file_export']['username'],
      password: HyperTrail::CONFIG['audit_log_file_export']['password']
    }
  end

  def export_job_id_url(job_id)
    format((HyperTrail::CONFIG['audit_log_file_export']['api_endpoint']).to_s,
           account_id: Account.current.id, job_id: job_id)
  end

  def set_temp_file
    format(AuditLogConstants::TEMP_FILE, time: Time.zone.now.strftime('%Y-%m-%d'), id: Account.current.id)
  end

  def translate_json_file(csv_file, url, job_id)
    filename = "tmp/#{job_id}.tar.gz"
    File.open(filename, 'wb') do |file|
      file.binmode
      HTTParty.get(url, stream_body: true) do |fragment|
        file.write(fragment)
      end
    end
    system("tar -xf #{filename} -C tmp/")
    file = open("tmp/#{job_id}.json")
    return 0 if File.size(file).zero?
    CSV.open(csv_file, 'wb') do |csv|
      csv << AuditLogConstants::COLUMN_HEADER
    end
    file.each_line do |line|
      hash_line = JSON.parse(line).deep_symbolize_keys
      report_data = enrich_json_file(hash_line)
      export_csv(report_data, csv_file)
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
    report_data.merge! event_type_and_description(activity, action, event_type)
    report_data
  end

  def write_to_s3(export_file, receive_via, job_id)
    file_path = "audit_log/#{Account.current.id}"
    write_options = { content_type: 'text/csv' }
    file = File.open(export_file)
    AwsWrapper::S3Object.store(file_path, file, S3_CONFIG[:bucket], write_options)
    upload_file export_file
    hash_file_name = job_id
    @data_export.save_hash!(hash_file_name)
    url = Rails.application.routes.url_helpers.download_file_url(@data_export.source, hash_file_name,
                                                                 host: Account.current.host,
                                                                 protocol: 'https')
    DataExportMailer.send_email(:audit_log_export, audit_log_email_params(url)[:user], audit_log_email_params(url)) if receive_via == AuditLogConstants::RECEIVE_VIA[0]
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
