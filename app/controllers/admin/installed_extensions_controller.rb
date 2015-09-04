class Admin::InstalledExtensionsController <  Admin::AdminController
  include Marketplace::ApiMethods

  after_filter :clear_installed_cache, :only => [:install, :reinstall, :uninstall, 
                                                 :enable, :disable]

  rescue_from Exception, :with => :mkp_connection_failure

  def new_configs
    install_extension = extension_configs.blank? ? 
                          data_from_url_params : 
                          data_from_url_params.merge({:configs => extension_configs})
    render :json => install_extension
  end

  def edit_configs
    install_extension = account_configs.blank? ? 
                          data_from_url_params : 
                          data_from_url_params.merge({:configs => account_configs})
    render :json => install_extension
  end

  def install
    install_extension(install_params)
    render :json => { 
      :status => @post_api.code 
    }
  end

  def reinstall
    update_extension(install_params)
    render :json => { 
      :status => @put_api.code
    }
  end

  def uninstall
    response = uninstall_extension
    render :json => response.merge({ :status => @delete_api.code })
  end

  def feedback
    feedback = post_feedback(feedback_params)
    status_code = feedback.code
  rescue => e
    status_code = 500
    Rails.logger.error("Error while submitting app feedback for version_id #{params[:version_id]} \n#{e.message}\n#{e.backtrace.join("\n")}")
    NewRelic::Agent.notice_error(e)
  ensure
    respond_to do |format|
      format.js do
        render :partial => '/admin/marketplace/templates/installed_freshplugs/app_feedback', 
                 :formats => [:rjs], :locals => { :version_id => params[:version_id], :status_code => status_code == 200 }
      end
    end
  end

  def enable
    update_extension(enable_params)
    render :json => { 
      :status => @put_api.code
    }
  end

  def disable
    update_extension(disable_params)
    render :json => {
      :status => @put_api.code
    }
  end

  private

    def install_params
      { :configs => params[:configs], 
        :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled] 
      }
    end

    def enable_params
      { :enabled => Marketplace::Constants::EXTENSION_STATUS[:enabled] }
    end

    def disable_params
      { :enabled => Marketplace::Constants::EXTENSION_STATUS[:disabled] }
    end

    def feedback_params
      { 
        :sender_name => current_user.name,
        :sender_email => current_user.email,
        :description => params[:description]
      }
    end

    def clear_installed_cache
      Marketplace::Constants::DISPLAY_PAGE.each do |page, id|
        page_key = MemcacheKeys::INSTALLED_FRESHPLUGS % { 
          :page => id, 
          :account_id => current_account.id 
        }
        MemcacheKeys.delete_from_cache page_key
      end
    end
end
