module HelpdeskReports::Export::Utils
  
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include HelpdeskReports::Export::Constants
  
  def set_current_account account_id
    Account.find(account_id).make_current
  end
  
  def set_current_user user_id
    Account.current.users.find(user_id).make_current
  end
  
  def set_locale
    I18n.locale =  (User.current && User.current.language) ? User.current.language : I18n.default_locale
  end
  
  def set_default_locale
    I18n.locale = I18n.default_locale
  end
  
  def build_file file_string, format
    begin
      file_name = "#{formatted_file_name}-#{Time.now.utc.strftime("%b-%d-%Y-%H:%M")}-#{SecureRandom.urlsafe_base64(4)}.#{format}"
      file_path = generate_file_path("bi_reports", file_name)
      write_file(file_string, file_path)
      
      set_attachment_method file_path
      
      upload_file(file_path, file_name) if @attachment_via_s3
    rescue Exception => err
      err_notification err
    ensure
      remove_export_file(file_path) if (File.exist?(file_path) && @attachment_via_s3)
    end
    file_path
  end
  
  def formatted_file_name
    REPORTS_NAME_MAPPING[report_type].gsub(" ","_").underscore
  end
  
  def user_download_url file_name, export_type
    "#{Account.current.full_url}/#{v2_reports_path}/#{export_type}/#{@today}/#{file_name}"
  end
  
  def v2_reports_path
    "reports/v2/download_file"
  end
  
  def generate_file_path type, file_name
    output_dir = "#{Rails.root}/tmp/export/#{Account.current.id}/#{type}" 
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{file_name}"
    file_path
  end
  
  def upload_file(file_path, file_name)
    path = s3_path file_name, "report_export"
    file = File.open(file_path)
    write_options = { :content_type => file.content_type,:acl => "public-read" }
    AwsWrapper::S3Object.store(path, file, S3_CONFIG[:bucket], write_options)
  end
  
  def s3_path file_name, export_type
    "data/helpdesk/#{export_type}/#{Rails.env}/#{User.current.id}/#{@today}/#{file_name}"
  end
  
  def set_attachment_method file_path
    size_from_redis    = get_reports_redis_key BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES
    max_size_allowed   = size_from_redis ? size_from_redis.to_i : HelpdeskReports::Constants::Ticket::MAIL_ATTACHMENT_LIMIT_IN_BYTES
    @attachment_via_s3 = File.size(file_path) > max_size_allowed
  end
  
  def remove_export_file(file_path)
    FileUtils.rm_f(file_path)
  end
  
  def err_notification err
    NewRelic::Agent.notice_error(err)
    puts err.inspect
    puts err.backtrace.join("\n")
    subj_txt = "Reports pdf/csv exception for #{Account.current.id}"
    message  = "#{err.inspect}\n #{err.backtrace.join("\n")}"
    DevNotification.publish(SNS["reports_notification_topic"], subj_txt, message)
  end

  def generate_csv_string(objects, index = 0)
    return if objects.blank?
    CSVBridge.generate do |csv|
      csv_headers = headers.collect {|header| csv_hash[header]}
      csv << csv_headers if index && index.zero?
      objects.each do |object|
        csv << object
      end
    end
  end
  
end