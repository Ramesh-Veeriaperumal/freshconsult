class Admin::ContactFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  include Cache::Memcache::ContactField
  include Cache::Memcache::Account

  def update
    super
    clear_contact_fields_cache
    clear_requester_widget_fields_from_cache
    if @errors.empty?
      redirect_to :action => :index
    else
      render :action => :index
    end
  end
  
  private

    def scoper_class
      ContactField
    end

    def index_scoper
      @index_scoper ||= current_account.contact_form.contact_fields # ||= saves MemCache calls
      @index_scoper.reject { |f| f.name == "client_manager" }
    end
end
