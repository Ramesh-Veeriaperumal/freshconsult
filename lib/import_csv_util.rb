# encoding: utf-8
require 'csv'
module ImportCsvUtil

  include Redis::RedisKeys
  include Redis::OthersRedis

  ONE_MEGABYTE  = 1000000
  CUSTOMER_TYPE = ["contact", "company", "agent_skill"]
  IMPORT_DELIMITER = "||"
  VALID_CLIENT_MANAGER_VALUES = ["yes", "true"]
  AND_SYMBOL = "&"
  IMPORT_BATCH_SIZE = 25

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def import_fields
    Rails.logger.debug("Import File uploaded :: #{params[:file]} Type: #{params[:type]} File size #{params[:file].size}")
    store_file params[:type]
    read_file session[:map_fields][:file_path],true
    @fields = current_account.safe_send("#{params[:type]}_form").safe_send("#{params[:type]}_fields").map{|f| {
      :name  => f.name, 
      :label => f.label
    }}
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
    save_row_count row_count, type

    AwsWrapper::S3Object.store(file_path, file_field.tempfile, S3_CONFIG[:bucket], :content_type => file_field.content_type)

    session[:map_fields] = {}
    session[:map_fields][:file_name] = file_field.original_filename
    session[:map_fields][:file_path] = file_path
  end

  def save_row_count count, type
    key = Object.const_get("#{type.upcase}_IMPORT_TOTAL_RECORDS") % {:account_id => 
                                                                          Account.current.id}
    set_others_redis_with_expiry(key, count, {})
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


  def file_info
    @file_name = session[:map_fields][:file_name]
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

  def delete_import_file(file_location)
    AwsWrapper::S3Object.delete(file_location, S3_CONFIG[:bucket])
  end
end 
