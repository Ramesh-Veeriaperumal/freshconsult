class Admin::ContactFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  include Cache::Memcache::ContactField

  def update
    super
    clear_contact_fields_cache
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
    end

end
