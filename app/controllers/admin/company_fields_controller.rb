class Admin::CompanyFieldsController < Admin::AdminController

  inherits_custom_fields_controller

  include Cache::Memcache::CompanyField

  def update
    super
    clear_company_fields_cache
    if @errors.empty?
      redirect_to :action => :index
    else
      render :action => :index
    end
  end
  
  private

    def scoper_class
      CompanyField
    end

    def index_scoper
      @index_scoper ||= current_account.company_form.company_fields_from_cache # ||= saves MemCache calls
    end
end
