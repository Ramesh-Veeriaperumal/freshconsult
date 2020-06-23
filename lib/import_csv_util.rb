# encoding: utf-8
require 'csv'
module ImportCsvUtil

  include Redis::RedisKeys
  include Redis::OthersRedis

  FIVE_MEGABYTE = 5_000_000
  CUSTOMER_TYPE = ["contact", "company", "agent_skill"]
  IMPORT_DELIMITER = "||"
  VALID_CLIENT_MANAGER_VALUES = ["yes", "true"]
  AND_SYMBOL = "&"
  IMPORT_BATCH_SIZE = 25
  IMPORT_KEY_EXPIRY = 30.days.to_i
  TWITTER_REQUESTER_FIELDS = %w[twitter_profile_status twitter_followers_count].freeze
  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def import_fields
    Rails.logger.debug("Import File uploaded :: #{params[:file]} Type: #{params[:type]} File size #{params[:file].size}")
    store_file params[:type]
    read_file session[:map_fields][:file_path],true
    @fields = current_account.safe_send("#{params[:type]}_form").safe_send("#{params[:type]}_fields").map{|f| {
      :name  => f.name, 
      :label => f.label
    }}
    @fields.reject! { |field| TWITTER_REQUESTER_FIELDS.include?(field[:name]) }
    if params[:type] == 'contact' && Account.current.multiple_user_companies_enabled?
      cm_field = current_account.contact_form.fetch_client_manager_field
      @fields.append({:name  => cm_field.name,
                       :label => cm_field.label})
    end
  end

  def store_file type
    file_field = params[:file]
    file_path  = "import/#{Account.current.id}/#{type}/#{Time.now.to_i}/#{file_field.original_filename}"
    output, status= Open3.capture2('wc','-l', file_field.path)
    row_count = output.strip.split(' ')[0].to_i

    AwsWrapper::S3Object.store(file_path, file_field.tempfile, S3_CONFIG[:bucket], :content_type => file_field.content_type)
    session[:map_fields] = {}
    session[:map_fields][:row_count] = row_count
    session[:map_fields][:file_name] = file_field.original_filename
    session[:map_fields][:file_path] = file_path
  end

  def set_counts(type)
    key = format(Object.const_get("#{type.upcase}_IMPORT_TOTAL_RECORDS"),
                 account_id: Account.current.id,
                 import_id: @import.id)
    set_others_redis_with_expiry(key, @row_count, ex: IMPORT_KEY_EXPIRY)

    ['IMPORT_FINISHED_RECORDS', 'IMPORT_FAILED_RECORDS'].each do |key_type|
      key = format(Object.const_get("#{type.upcase}_#{key_type}"),
                   account_id: Account.current.id,
                   import_id: @import.id)
      set_others_redis_with_expiry(key, 0, ex: IMPORT_KEY_EXPIRY)
    end
  end

  def read_file file_location, header = false
    @rows = []
    csv_file = AwsWrapper::S3Object.find(file_location, S3_CONFIG[:bucket])
    CSVBridge.parse(content_of(csv_file)) do |row|
      @rows << row.collect{|r| Helpdesk::HTMLSanitizer.clean(r.to_s)}
      break if header && @rows.size == 2
    end
  rescue => e
    Rails.logger.error "Error while reading csv data ::#{e.message}\n#{e.backtrace.join("\n")}"
    NewRelic::Agent.notice_error(e, {:description => "The file format is not supported. Please check the CSV file format!"})
    raise e
  end

  def fetch_import_details(import)
    @import_item = { id: import.id,
                     created_at: import.created_at,
                     status: fetch_status_value(import) }
    status = calculate_status(import)
    @import_item.merge!(status)
    @import_item[:failures] = fetch_failures(import)
    @import_item
  end

  def calculate_status(import)
    status = {}
    key = format(Object.const_get("#{import_type.upcase}_IMPORT_TOTAL_RECORDS"),
                 account_id: Account.current.id,
                 import_id: import.id)
    total_rows = get_others_redis_key(key).to_i
    status[:total_records] = total_rows if total_rows.nonzero?

    key = format(Object.const_get("#{import_type.upcase}_IMPORT_FINISHED_RECORDS"),
                 account_id: Account.current.id,
                 import_id: import.id)
    completed_rows = get_others_redis_key(key).to_i
    status[:completed_records] = completed_rows if completed_rows.nonzero?

    if status[:completed_records] && fetch_status_value(import) == 'in_progress'
      @import_item[:estimated_time_remaining] = calculate_time_remaining(import, status)
    end
    status
  end

  def fetch_failures(import)
    failures = {}
    key = format(Object.const_get("#{import_type.upcase}_IMPORT_FAILED_RECORDS"),
                 account_id: Account.current.id,
                 import_id: import.id)
    failure_count = get_others_redis_key(key).to_i
    failures[:count] = failure_count if failure_count.nonzero?
    attachment = import.attachments.first
    if attachment
      url = attachment.attachment_url_for_api(true, :original, 5.minutes)
      failures[:report] = url
    end
    failures
  end

  def calculate_time_remaining(import, status)
    time_taken = (Time.now.utc - import.created_at.utc)
    time_remaining = ((status[:total_records] - status[:completed_records]) * time_taken) / (status[:completed_records])
    [time_remaining / 3600, time_remaining / 60 % 60,
      time_remaining % 60].map { |t| t.to_i.to_s.rjust(2, '0') }.join(':')
  end

  def fetch_status_value(import)
    if in_progress_values.include?(import.import_status)
      'in_progress'
    else
      Admin::DataImport::IMPORT_STATUS.key(import.import_status)
    end
  end

  def in_progress_values
    Admin::DataImport::IMPORT_STATUS.values_at(*Admin::DataImport::IN_PROGRESS_STATUS)
  end

  def file_info
    @file_name = session[:map_fields][:file_name]
    @row_count = session[:map_fields][:row_count]
    @file_location = session[:map_fields][:file_path]
  end

  def to_hash(rowarray)
    rowarray.each_with_index.map { |x,i| [x,i] }
  end

  def content_of csv_file
    csv_file.read.force_encoding('utf-8').encode('utf-16', :undef => :replace, :invalid => :replace, :replace => '').encode('utf-8')
  end

  def file_name
    session[:map_fields][:file_name]
  end

  def file_location
    session[:map_fields][:file_path]
  end

  def row_count
    @row_count ||= session[:map_fields][:row_count]
  end

  def delete_import_file(file_location)
    AwsWrapper::S3Object.delete(file_location, S3_CONFIG[:bucket])
  end
end 
