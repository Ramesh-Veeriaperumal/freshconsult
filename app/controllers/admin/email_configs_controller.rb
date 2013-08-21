require "httparty"

class Admin::EmailConfigsController < Admin::AdminController
  include ModelControllerMethods

  before_filter :only => [:new] do |c|
    c.requires_feature :multiple_emails
  end
  
  def index
    @email_config = current_account.primary_email_config
    @global_email_configs = current_account.global_email_configs
    @products = current_account.products
    @account_additional_settings = current_account.account_additional_settings
  end
  
  def new
    @products = current_account.products
    @groups = current_account.groups
  end

  def edit
    @products = current_account.products
    @groups = current_account.groups
  end
  
  def test_email
    @email_config = current_account.primary_email_config
    emailObj = EmailConfigNotifier.deliver_test_email(current_account.primary_email_config)
    
    render :json => {:email_sent => true}.to_json 
    
  end
  
  def make_primary 
    @email_config = scoper.find(params[:id])
    if @email_config && @email_config.update_attributes(:primary_role => true)
        flash[:notice] = t(:'flash.email_settings.make_primary.success', :reply_email => @email_config.reply_email)
    end
    redirect_back_or_default redirect_url
  end
  
  def register_email
    @email_config = scoper.find_by_activator_token params[:activation_code]
    if @email_config
      unless @email_config.active
        @email_config.active = true
        flash[:notice] = t(:'flash.email_settings.activation.success', 
            :reply_email => @email_config.reply_email) if @email_config.save
      else
        flash[:warning] = t(:'flash.email_settings.activation.already_activated', 
            :reply_email => @email_config.reply_email)
      end
    else
      flash[:warning] = t(:'flash.email_settings.activation.invalid_code')
    end
    
    redirect_back_or_default redirect_url
  end
  
  def deliver_verification
    @email_config = scoper.find(params[:id])

    remove_bounced_email(@email_config.reply_email) # remove the email from bounced email list so that 'resend verification' will send mail again.

    @email_config.set_activator_token
    @email_config.save

    flash[:notice] = t(:'flash.email_settings.send_activation.success', 
        :reply_email => @email_config.reply_email)

    redirect_to :back
  end
  
  def personalized_email_enable    
    current_account.features.personalized_email_replies.create
    current_account.reload  
  end
  
  def personalized_email_disable
    current_account.features.personalized_email_replies.destroy
    current_account.reload   
  end

  private
    # This method uses send grid api to remove the supplied email from send grid bounce list
    def remove_bounced_email (bounced_email_addr)
      send_grid_credentials = Helpdesk::EMAIL[:outgoing][RAILS_ENV.to_sym]
      Rails.logger.debug "Start remove_bounced_email " +bounced_email_addr
      begin
        unless (bounced_email_addr.blank? or send_grid_credentials.blank?)
          send_grid_response = HTTParty.get("https://sendgrid.com/api/bounces.delete.xml?api_user=#{send_grid_credentials[:user_name]}&api_key=#{send_grid_credentials[:password]}&email=#{bounced_email_addr}", {}) 
          send_grid_res_hash = Hash.from_xml(send_grid_response)
          result_msg = send_grid_res_hash["result"] || send_grid_res_hash["errors"] unless (send_grid_res_hash.nil?)
        end
        Rails.logger.info "Removing email id " +bounced_email_addr+" from send gird bounced list resulted in "+result_msg.to_s
      rescue => e
        Rails.logger.error("Error during removing bounced email #{bounced_email_addr} from send grid. \n#{e.message}\n#{e.backtrace.join("\n")}")
      end
    end

  protected
    def scoper
      current_account.all_email_configs
    end
 
    def human_name
      I18n.t('email_configs.email')
    end
  
    def create_flash
      I18n.t('email_configs.email_added_succ_msg')
    end
    
    def create_error #Need to refactor this code, after changing helpcard a bit.
      @products = current_account.products
      @groups = current_account.groups 
    end
    
    def update_error
      @products = current_account.products
      @groups = current_account.groups
    end    
end
