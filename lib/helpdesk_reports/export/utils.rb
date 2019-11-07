module HelpdeskReports::Export::Utils
  
  include Redis::RedisKeys
  include Redis::ReportsRedis
  include HelpdeskReports::Constants::Export
  
  def set_locale
    I18n.locale =  (User.current && User.current.language) ? User.current.language : I18n.default_locale
  end
  
  def build_file file_string, format, report_type, export_type, scheduled_report=false
    report_name = REPORTS_NAME_MAPPING[report_type]
    filter_name = (defined?(params) && params[:filter_name]) ? "#{report_name}_#{params[:filter_name]}" : report_name 
    filter_name = filter_name.gsub(/[\s+\/]/,'_').underscore
    file_name   = "#{filter_name}-#{Time.current.strftime("%d-%b-%y-%H-%M")}-#{SecureRandom.urlsafe_base64(4)}.#{format}"
    file_path   = generate_file_path("bi_reports", file_name)

    write_file(file_string, file_path)
    set_attachment_method(file_path) unless scheduled_report
    upload_file(file_path, file_name, export_type) if @attachment_via_s3
    file_path
  end

  def export_path export_id
    "#{Rails.root}/tmp/export/#{Account.current.id}/bi_reports/#{export_id}"
  end

  def s3_export_path export_id, file_name
    "data/helpdesk/#{TICKET_EXPORT_TYPE}/#{Rails.env}/#{User.current.id}/#{export_id}/#{file_name}"
  end

  def generate_dir export_id
    FileUtils.mkdir_p export_path(export_id)
  end

  def dir_exists? export_id
    File.exists? export_path(export_id)
  end

  def batch_file_exists? export_id, file
    AwsWrapper::S3Object.find(s3_export_path(export_id, file), S3_CONFIG[:bucket]).exists?
  end

  def write_file file_string, file_path
    File.open(file_path , "wb") do |f|
      f.write(file_string)
    end
  end

  def upload_batch_file export_id, batch_id, file_string, format
    file_name = "batch_#{batch_id}.#{format}"
    file_path = "#{export_path(export_id)}/#{file_name}"
    write_file file_string, file_path
    upload_file(file_path, file_name, TICKET_EXPORT_TYPE ,export_id)
    File.delete(file_path)
  end

  def append_batch_content_to_csv csv, export_id, file_name
    s3_path = s3_export_path(export_id, file_name)
    csv_file = AwsWrapper::S3Object.find(s3_path, S3_CONFIG[:bucket])
    CSVBridge.parse(csv_file.read)[1..-1].each do |row|
      csv << row.collect{|con| con.nil? ? "" : (CGI.escapeHTML con)}
    end
    AwsWrapper::S3Object.delete(s3_path, S3_CONFIG[:bucket])
  end

  def generate_file_path type, file_name
    output_dir = "#{Rails.root}/tmp/export/#{Account.current.id}/#{type}" 
    FileUtils.mkdir_p output_dir
    file_path = "#{output_dir}/#{file_name}"
    file_path
  end
  
  def upload_file(file_path, file_name, export_type ,export_id=nil)
    if export_id
      path = s3_export_path(export_id, file_name)
    else
      path = "data/helpdesk/#{export_type}/#{Rails.env}/#{User.current.id}/#{@today || DateTime.now.utc.strftime('%d-%m-%Y')}/#{file_name}"
    end
    file = File.open(file_path)
    write_options = { :content_type => MIME::Types.type_for(file_path).first.content_type,:acl => "public-read" }
    AwsWrapper::S3Object.store(path, file, S3_CONFIG[:bucket], write_options)
  end
  
  def set_attachment_method file_path
    size_from_redis    = get_reports_redis_key BI_REPORTS_MAIL_ATTACHMENT_LIMIT_IN_BYTES
    max_size_allowed   = size_from_redis ? size_from_redis.to_i : HelpdeskReports::Constants::Export::MAIL_ATTACHMENT_LIMIT_IN_BYTES
    @attachment_via_s3 = Account.current.secure_attachments_enabled? || (File.size(file_path) > max_size_allowed)
  end

  def content_of csv_file
    csv_file.read.force_encoding('utf-8').encode('utf-16', :undef => :replace, :invalid => :replace, :replace => '').encode('utf-8')
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
