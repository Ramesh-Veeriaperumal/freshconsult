# encoding: utf-8
require 'csv'
module ImportCsvUtil

  ONE_MEGABYTE = 1000000

  #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def map_fields
    params.symbolize_keys!
    Rails.logger.debug("File uploaded: #{params[:file]}")
    if session[:map_fields].nil? || !params[:file].blank?
      return @map_fields_error = MissingFileContentsError if params[:file].blank?
      store_file
    else
      if session[:map_fields][:file].nil? || params[:fields].nil?
        session[:map_fields] = nil
        @map_fields_error =  InconsistentStateError
      else
        @file_name = session[:map_fields][:file_name]
        @file_location = session[:map_fields][:file]
      end
    end

    unless @map_fields_error
      read_file session[:map_fields][:file],true
      @fields = current_account.send("#{params[:type]}_form").fields.collect { |field| {:name => field.name, :label => field.label} }
    end
  end

  def store_file
    file_field = params[:file]
    file_path = "csv_#{Account.current.id}/#{Time.now.to_i}/#{file_field.original_filename}"
      AwsWrapper::S3Object.store(
            file_path,
            file_field,
            S3_CONFIG[:bucket],
            :content_type => file_field.content_type
      )
    session[:map_fields] = {}
    session[:map_fields][:file_name] = file_field.original_filename
    session[:map_fields][:file] = file_path
  end

  def read_file file_location, header = false
    @rows = []
    begin
      csv_file = AwsWrapper::S3Object.find(file_location, S3_CONFIG[:bucket])
      CSVBridge.parse(content_of(csv_file)) do |row|
        @rows << row
        break if header && @rows.size == 2
      end
    rescue CSVBridge::MalformedCSVError => e
      @map_fields_error = e
      Rails.logger.error "Error while reading csv data ::#{e.message}\n#{e.backtrace.join("\n")}"
      NewRelic::Agent.notice_error(e,{:description => "The file format is not supported. Please check the CSV file format!" })
      raise @map_fields_error unless header
    end
  end

  def content_of csv_file
    csv_file.read.force_encoding('utf-8').encode('utf-16', :undef => :replace, :invalid => :replace, :replace => '').encode('utf-8')
  end

  def delete_empty_parameters
    @field_params = params[:fields]
    @field_params.delete_if {|key, value| value.blank? }
  end

  def customer_params
    { 
      :account_id => current_account.id,
      :email => current_user.email,
      :type => params[:type],
      :customers =>{
        :file_name => @file_name,
        :file_location => @file_location,
        :fields =>  @field_params,
      }
    }
  end

  def fields_mapped?
    raise @map_fields_error if @map_fields_error
    delete_empty_parameters if params[:fields]
    !params[:fields].blank? && @rows.size > 1 
  end

  def map_fields_cleanup
    unless params[:fields].nil?
      session[:map_fields] = nil
      @map_fields_error = nil
    end
  end

  class InconsistentStateError < StandardError
  end

  class MissingFileContentsError < StandardError
  end
end 