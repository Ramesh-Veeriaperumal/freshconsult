class CustomersImportController < ApplicationController
   include Helpdesk::ToggleEmailNotification
   include ImportCsvUtil

   before_filter :disable_user_activation
   after_filter :enable_notification
   before_filter :map_fields, :only => :create
   after_filter :map_fields_cleanup, :only => :create

   #------------------------------------Customers include both contacts and companies-----------------------------------------------

  def csv
    redirect_to "/#{params[:type].pluralize}", :flash => { :notice => t(:'flash.import.already_running')} if current_account.send("#{params[:type]}_import")
  end 
  
  def create
    if fields_mapped?
      params[:type].eql?("company") ? Resque.enqueue(Workers::Import::CompaniesImport, customer_params) : 
                  Resque.enqueue(Workers::Import::ContactsImport, customer_params)
      current_account.send(:"create_#{params[:type]}_import",{:status => 1})
      redirect_to "/#{params[:type].pluralize}", :flash =>{ :notice => t(:'flash.import.success')}
    else
      render
    end
    rescue CSVBridge::MalformedCSVError => e
      redirect_to "/imports/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.wrong_format')}
    rescue ImportCsvUtil::InconsistentStateError
      redirect_to "/imports/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.failure')}
    rescue ImportCsvUtil::MissingFileContentsError
      redirect_to "/imports/#{params[:type]}", :flash=>{:error =>t(:'flash.customers_import.no_file')}
  end
end