class Admin::ContactFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  def update
    super
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
      @index_scoper ||= current_account.contact_form.contact_fields_from_cache # ||= saves MemCache calls
    end

end
