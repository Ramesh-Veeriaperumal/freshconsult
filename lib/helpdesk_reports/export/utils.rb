module HelpdeskReports::Export::Utils
  
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include HelpdeskReports::Constants::Export
  
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
  
  def build_file file_string, format, export_type
    report_name = REPORTS_NAME_MAPPING[report_type].gsub(" ","_").underscore
    file_name   = "#{report_name}-#{Time.now.utc.strftime("%b-%d-%Y-%H:%M")}-#{SecureRandom.urlsafe_base64(4)}.#{format}"
    file_path   = generate_file_path("bi_reports", file_name)

    write_file(file_string, file_path)
    set_attachment_method(file_path)
    upload_file(file_path, file_name, export_type) if @attachment_via_s3 
    file_path
  end

  def generate_file_path type, file_name
    output_dir = "#{Rails.root}/tmp/export/#{Account.current.id}/#{type}" 
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{file_name}"
    file_path
  end
  
  def upload_file(file_path, file_name, export_type)
    path = "data/helpdesk/#{export_type}/#{Rails.env}/#{User.current.id}/#{@today}/#{file_name}"
    file = File.open(file_path)
    write_options = { :content_type => file.content_type,:acl => "public-read" }
    AwsWrapper::S3Object.store(path, file, S3_CONFIG[:bucket], write_options)
  end
  
  def set_attachment_method file_path
    size_from_redis    = get_reports_redis_key BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES
    max_size_allowed   = size_from_redis ? size_from_redis.to_i : HelpdeskReports::Constants::Export::MAIL_ATTACHMENT_LIMIT_IN_BYTES
    @attachment_via_s3 = File.size(file_path) > max_size_allowed
  end

  def generate_csv_string(objects, index = 0)
    return if objects.blank?
    csv_headers = headers.collect {|header| csv_hash[header]}
    CSVBridge.generate do |csv|
      csv << csv_headers if index && index.zero?
      objects.each do |object|
        csv << object
      end
    end
  end
  
end