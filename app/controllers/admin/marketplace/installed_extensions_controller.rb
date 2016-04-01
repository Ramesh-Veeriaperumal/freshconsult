class Admin::Marketplace::InstalledExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods
  include Marketplace::ApiUtil

  rescue_from Exception, :with => :mkp_exception

  def new_configs
    extn_configs = extension_configs
    render_error_response and return if error_status?(extn_configs)
    @configs = extn_configs.body
    render 'admin/marketplace/installed_extensions/configs', :status => extn_configs.status
  end
 
  def edit_configs
    extn_configs = extension_configs
    render_error_response and return if error_status?(extn_configs)

    acc_config = account_configs
    render_error_response and return if error_status?(acc_config)

    @configs = account_configurations(extn_configs.body, acc_config.body)
    render 'admin/marketplace/installed_extensions/configs', :status => extn_configs.status
  end

  def install
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)
    
    install_ext = install_extension(install_params(extn_details.body))
    flash[:notice] = t('marketplace.install_action.success')
    render :nothing => true, :status => install_ext.status 
  end

  def reinstall
    extn_details = extension_details
    render_error_response and return if error_status?(extn_details)

    update_ext = update_extension(install_params(extn_details.body))
    flash[:notice] = t('marketplace.update_action.success')
    render :nothing => true, :status => update_ext.status
  end

  def uninstall
    uninstall_ext = uninstall_extension(uninstall_params)
    render :nothing => true, :status => uninstall_ext.status
  end

  def enable
    update_ext = update_extension(enable_params)
    render :nothing => true, :status => update_ext.status
  end

  def disable
    update_ext = update_extension(disable_params)
    render :nothing => true, :status => update_ext.status
  end

  private

    def install_params(extn_details)
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :configs => params[:configs], 
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled],
        :type => extn_details['type'],
        :options => extn_details['options'],
      }
    end

    def uninstall_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id]
      }
    end

    def enable_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled] }
    end

    def disable_params
      { :extension_id => params[:extension_id],
        :version_id => params[:version_id],
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:disabled] }
    end

    def account_configurations(configs, acc_configs)
      @account_configurations = []
      configs.each do |config|
        if config['field_type'] == Marketplace::Constants::FORM_FIELD_TYPE[:text]
          config['default_value'] = acc_configs[config['name']]
        else
          config['default_value'].delete(acc_configs[config['name']])
          config['default_value'].unshift(acc_configs[config['name']])
        end
        @account_configurations << config
      end
      @account_configurations
    end
end
