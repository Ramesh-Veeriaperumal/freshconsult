module Admin
  class ApiDataExportsController < ApiApplicationController
    include HelperConcern
    
    def account_export 
      data_export_delegator = DataExportDelegator.new(@item)
      if data_export_delegator.invalid?(action_name.to_sym)
        render_custom_errors(data_export_delegator, true)
      else
        set_export_status
        params = {:domain => current_account.full_domain,
                  :email => current_user.email}
        Export::DataExport.perform_async(params)
        head 204
      end
    end
    
    private
    
    def set_export_status
      @item = scoper.new(:user => current_user,
                         :source => DataExport::EXPORT_TYPE[:backup])
      @item.save
    end
    
    def scoper
      current_account.data_exports
    end
    
    def constants_class
      :DataExportConstants.to_s.freeze
    end
    
    def load_object
      @item = scoper.data_backup[0]
    end
  end
  
end