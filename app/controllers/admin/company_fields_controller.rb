class Admin::CompanyFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  before_filter :remove_custom_company_fields, :if => :custom_company_fields_disabled?, :only => [:update]

  include Cache::Memcache::CompanyField
  include Cache::Memcache::Account
  include Helpdesk::CustomFields::CustomFieldMethods

  def update
    super
    clear_company_fields_cache
    clear_requester_widget_fields_from_cache
    response_data = index_scoper if @errors.blank?
    invoke_respond_to(@errors.squish, response_data) do
      if @errors.empty?
        redirect_to :action => :index
      else
        render :action => :index
      end
    end
  end
  
  private

    def custom_company_fields_disabled?
      !current_account.custom_company_fields_enabled?
    end

    def remove_custom_company_fields
      @fields = JSON.parse params[:jsonData]
      @fields.select! { |field| field["field_type"].include? "default" }
      @params_modified = true
    end

    def scoper_class
      CompanyField
    end

    def index_scoper
      @index_scoper ||= current_account.company_form.company_fields_from_cache # ||= saves MemCache calls
    end
end
