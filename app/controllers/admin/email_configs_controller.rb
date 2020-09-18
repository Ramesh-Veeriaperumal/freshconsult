require "httparty"
require 'net/smtp'
require 'net/imap'

class Admin::EmailConfigsController < Admin::AdminController
  include ModelControllerMethods
  include MailboxValidator
  include Redis::RedisKeys
  include Redis::OthersRedis
  include Admin::EmailConfig
  include Admin::EmailConfig::Utils
  include Email::Mailbox::Utils

  before_filter only: [:new, :create] do |c|
    c.requires_this_feature :multiple_emails
  end

  before_filter :load_imap_error_mapping, only: [:edit]

  def index
    @email_config = current_account.primary_email_config
    @global_email_configs = current_account.global_email_configs
    @products = current_account.products
    @account_additional_settings = current_account.account_additional_settings
  end
  
  def google_signin
    redis_key = populate_redis_oauth(params.except(:action, :controller), 'gmail')
    redirect_to(gmail_oauth_url('account_id' => current_account.id, 'r_key' => redis_key)) && return
  end

  def microsoft_signin
    redis_key = populate_redis_oauth(params.except(:action, :controller), 'outlook')
    redirect_to(outlook_oauth_url('account_id' => current_account.id, 'r_key' => redis_key))
  end

  def existing_email
    email_config = current_account.all_email_configs.find_by_reply_email(params[:email_address])
    if email_config.nil?
      render :json => { :success => true, :message => "" }
    else
      render :json => { :success => false, :message => t('admin.products.form.email_address_present') }
    end
  end

  def new
    @imap_mailbox = @email_config.build_imap_mailbox
    @smtp_mailbox = @email_config.build_smtp_mailbox
    @products = current_account.products
    @groups = current_account.groups.support_agent_groups
  end
  
  def edit
    @products = current_account.products
    @groups = current_account.groups.support_agent_groups
    @imap_mailbox = (@email_config.imap_mailbox || @email_config.build_imap_mailbox)
    @smtp_mailbox = (@email_config.smtp_mailbox || @email_config.build_smtp_mailbox)
  end

  def update
    @email_config.imap_mailbox.error_type = 0 if @email_config.imap_mailbox
    if @email_config.update_attributes(params[:email_config])
      respond_to do |format|
        format.html  do
          flash[:notice] = I18n.t(:'flash.general.update.success', :human_name => human_name)
          redirect_back_or_default redirect_url
        end
        format.js
      end
    else
      update_error
      render :action => 'edit'
    end
  end

  def test_email
    @email_config = current_account.primary_email_config
    EmailConfigNotifier.send_email(:test_email, nil, current_account.primary_email_config)

    render json: { email_sent: true }.to_json
  end

  def make_primary
    @email_config = scoper.find(params[:id])
    if @email_config && @email_config.update_attributes(:primary_role => true)
        flash[:notice] = t(:'flash.email_settings.make_primary.success', :reply_email => @email_config.reply_email).html_safe
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

  def toggle_agent_forward_setting
    if current_account.disable_agent_forward_enabled?
      current_account.disable_setting(:disable_agent_forward)
    else
      current_account.enable_setting(:disable_agent_forward)
    end
    post_process
  end

  def toggle_compose_email_setting
    if current_account.compose_email_enabled?
      current_account.disable_setting(:compose_email)
    else
      current_account.enable_setting(:compose_email)
      #Handle delta case. Will remove this code once we remove redis feature check.
      $redis_others.perform_redis_op("srem", COMPOSE_EMAIL_ENABLED,current_account.id)
    end
    post_process
  end

  def personalized_email_enable
    current_account.enable_setting(:personalized_email_replies)
    post_process
  end

  def personalized_email_disable
    current_account.disable_setting(:personalized_email_replies)
    post_process
  end

  def reply_to_email_enable
    current_account.enable_setting(:reply_to_based_tickets)
    post_process
  end

  def reply_to_email_disable
    current_account.disable_setting(:reply_to_based_tickets)
    post_process
  end

  def destroy
    @email_config = scoper.find(params[:id])
    if @email_config.primary_role
      flash[:notice] = t('email_configs.delete_primary_email')
      redirect_to :action => 'index' and return
    end
    @email_config.destroy

    respond_to do |format|
      format.html { redirect_to :action => 'index' }
      format.xml  { head :ok }
      format.json { head :ok }
    end
  end

  protected
    def scoper
      current_account.all_email_configs
    end

    def post_process
      current_account.reload
      flash[:notice] = t(:'email_configs.config_saved_message')
      render partial: 'show_message'
    end

    def human_name
      I18n.t('email_configs.email')
    end

    def create_flash
      I18n.t('email_configs.email_added_succ_msg')
    end

    def create_error #Need to refactor this code, after changing helpcard a bit.
      @imap_mailbox = @obj.imap_mailbox
      @smtp_mailbox = @obj.smtp_mailbox
      @products = current_account.products
      @groups = current_account.groups
    end

    def update_error
      @products = current_account.products
      @groups = current_account.groups
    end

    def load_imap_error_mapping
      if @email_config.imap_mailbox.present?
        error_type = @email_config.imap_mailbox.error_type.to_i
        @error_type = Admin::EmailConfig::Imap::ErrorMapper.new(error_type: error_type).fetch_error_mapping if error_type > 0
      end
    end
end
