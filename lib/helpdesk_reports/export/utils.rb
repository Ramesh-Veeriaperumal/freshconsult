module HelpdeskReports::Export::Utils
  
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include HelpdeskReports::Constants::Export
  
  def set_locale
    I18n.locale =  (User.current && User.current.language) ? User.current.language : I18n.default_locale
  end
  
  def build_file file_string, format, export_type
    report_name = REPORTS_NAME_MAPPING[report_type]
    filter_name = params[:filter_name] ? "#{report_name}_#{params[:filter_name]}" : report_name 
    filter_name = filter_name.gsub(" ","_").underscore
    file_name   = "#{filter_name}-#{Time.current.strftime("%d-%b-%y-%H:%M")}-#{SecureRandom.urlsafe_base64(4)}.#{format}"
    file_path   = generate_file_path("bi_reports", file_name)

    write_file(file_string, file_path)
    set_attachment_method(file_path)
    upload_file(file_path, file_name, export_type) if (@attachment_via_s3 && !params[:scheduled_report])
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

  # The below methods are used for modifying data for Timesheet,Chat and Phone reports

  def old_report_params params
    params[:data_hash].symbolize_keys!
    pdf_params = params[:data_hash][:report_filters].collect{ |filter| [filter['name'],filter['value']] }.to_h
    pdf_params.merge!(params)
    pdf_params[:select_hash] = params[:data_hash][:select_hash]
    pdf_params[:date_range] ||= params[:data_hash][:date]['date_range'] #temporary. date range for direct export.
    pdf_params
  end

end