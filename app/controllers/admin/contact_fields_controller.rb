class Admin::ContactFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  include Cache::Memcache::ContactField
  include Cache::Memcache::Account
  include Helpdesk::CustomFields::CustomFieldMethods

  def update
    super
    clear_contact_fields_cache
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

    def scoper_class
      ContactField
    end

    def index_scoper
      @index_scoper ||= current_account.contact_form.contact_fields # ||= saves MemCache calls
    end
end
