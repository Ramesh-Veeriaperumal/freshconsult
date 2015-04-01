class CustomersImportController < ApplicationController
   include ImportCsvUtil

   before_filter :set_selected_tab
   before_filter :validate_customer_type
   before_filter :validate_params, :only => [:map_fields, :create]
   before_filter :file_info, :only => :create

   #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def csv
    redirect_to "/#{params[:type].pluralize}", :flash => { :notice => t(:'flash.import.already_running')} if current_account.send("#{params[:type]}_import")
  end

  def map_fields
    import_fields
    @headers = to_hash(@rows.first)
    rescue
      redirect_to "/imports/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.wrong_format')}
  end 
  
  def create
    if fields_mapped?
      current_account.send(:"create_#{params[:type]}_import",{:status => 1})
      params[:type].eql?("company") ? Resque.enqueue(Workers::Import::Company, customer_params) : 
                  Resque.enqueue(Workers::Import::Contact, customer_params)
      redirect_to "/#{params[:type].pluralize}", :flash =>{ :notice => t(:'flash.import.success')}
    else
      redirect_to "/imports/#{params[:type]}"
    end
  end

  private

  def validate_customer_type
    redirect_to send(Helpdesk::ACCESS_DENIED_ROUTE) unless CUSTOMER_TYPE.include?(params[:type])
  end

  def validate_params
    params.symbolize_keys
    session_fields = session[:map_fields]
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
      :account_id => current_account.id,
      :email => current_user.email,
      :type => params[:type],
      :customers => {
        :file_name => @file_name,
        :file_location => @file_location,
        :fields =>  @field_params,
      }
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
end