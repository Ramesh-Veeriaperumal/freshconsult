# encoding: utf-8
require 'csv'
module ImportCsvUtil

  ONE_MEGABYTE  = 1000000
  CUSTOMER_TYPE = ["contact", "company"]

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def import_fields
    Rails.logger.debug("Import File uploaded :: #{params[:file]}")
    store_file
    read_file session[:map_fields][:file_path],true
    @fields = current_account.send("#{params[:type]}_form").send("#{params[:type]}_fields").map{|f| {
      :name  => f.name, 
      :label => f.label
    }}
  end

  def store_file
    file_field = params[:file]
    file_path  = "import/#{Account.current.id}/#{params[:type]}/#{Time.now.to_i}/#{file_field.original_filename}"

    AwsWrapper::S3Object.store(file_path, file_field.tempfile, S3_CONFIG[:bucket], :content_type => file_field.content_type)

    session[:map_fields] = {}
    session[:map_fields][:file_name] = file_field.original_filename
    session[:map_fields][:file_path] = file_path
  end

  def read_file file_location, header = false    
    @rows = []
    csv_file = AwsWrapper::S3Object.find(file_location, S3_CONFIG[:bucket])
    CSVBridge.parse(content_of(csv_file)) do |row|
      @rows << row
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
end 