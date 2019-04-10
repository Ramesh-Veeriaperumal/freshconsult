class CustomersImportController < ApplicationController
   include ImportCsvUtil
   include Redis::RedisKeys
   include Redis::OthersRedis
   before_filter :set_selected_tab
   before_filter :validate_customer_type
   before_filter :validate_params, :only => [:map_fields, :create]
   before_filter :file_info, :only => :create
   PRIVILEGE_MAP = {
    contact: :manage_contacts,
    company: :manage_companies,
   }

   #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def csv
    if current_account.safe_send("#{params[:type]}_imports").safe_send(:"running_#{params[:type]}_imports").present?
      redirect_to "/#{params[:type].pluralize}", flash: { notice: t(:'flash.import.already_running') }
    end
  end

  def map_fields
    import_fields
    @headers = to_hash(@rows.first)
  rescue => e
    redirect_to "/imports/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.wrong_format')}
    @import.failure!(e.message + "\n" + e.backtrace.join("\n")) if @import
  end
  
  def create
    if fields_mapped?
      @import = current_account.safe_send("#{params[:type]}_imports").create!(import_status: Admin::DataImport::IMPORT_STATUS[:started])
      set_counts params[:type]
      import_worker = params[:type].eql?("company") ?
        "Import::CompanyWorker" :
        "Import::ContactWorker"
      import_worker.constantize.perform_async(customer_params)
      redirect_to "/#{params[:type].pluralize}", :flash =>{ :notice => t(:'flash.import.success')}
    else
      redirect_to "/imports/#{params[:type]}"
    end
  end

  private

  def validate_customer_type
    redirect_to safe_send(Helpdesk::ACCESS_DENIED_ROUTE) unless CUSTOMER_TYPE.include?(params[:type])
  end

  def validate_params
    params.symbolize_keys
    session_fields = session[:map_fields]
    unless has_privilege?
      flash_msg = { notice: t(:'flash.general.insufficient_privilege.admin') }
      return redirect_to "/#{params[:type].pluralize}", flash: flash_msg
    end

    if session_fields.nil? || !params[:file].blank?
      redirect_to "/imports/#{params[:type]}", 
          :flash=>{:error =>t(:'flash.customers_import.no_file')} if params[:file].blank?
    else
      if session_fields[:file_path].nil? || session_fields[:file_name].nil? || params[:fields].blank?
        session.delete(:map_fields)
        redirect_to "/imports/#{params[:type]}", 
            :flash=>{:error =>t(:'flash.customers_import.failure')}
      end
    end
  end

  def customer_params
    { 
      account_id: current_account.id,
      email: current_user.email,
      type: params[:type],
      customers: {
        file_name: @file_name,
        file_location: @file_location,
        fields:  @field_params
      },
      data_import: @import.id
    }
  end

  def fields_mapped?
    clean_params 
    !params[:fields].blank?
  end

  def clean_params
    @field_params = params[:fields]
    @field_params.delete_if {|key, value| value.blank? }
    session.delete(:map_fields)
  end

  def set_selected_tab
    @selected_tab = :customers
  end

  def has_privilege?
    current_user.privilege? PRIVILEGE_MAP[params[:type].to_sym]
  end
end
