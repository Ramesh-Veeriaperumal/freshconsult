class Admin::OnboardingController < Admin::AdminController
  include Onboarding::OnboardingHelperMethods
  include Onboarding::AccountChannels
  include ChatHelper

  before_filter :set_user_email_config, :only => [:update_activation_email]
  before_filter :check_onboarding_finished, only: [:update_channel_configs]
  before_filter :parse_channel_config, only: [:update_channel_configs]

  def update_activation_email
    current_user.email = @user_email_config[:new_email]
    if current_user.save
      set_current_user_active
      update_account_config  
      add_to_crm
    end
  end

  def resend_activation_email
    current_user.send_activation_email
    render json: {result: true}
  end

  def update_channel_configs
    apply_account_channel_config
    complete_admin_onboarding
    render json: {result: true}
  end

  private
    def set_user_email_config
      @user_email_config = {
        old_email: current_user.email,
        new_email: params["admin_email_update"]["email"]
      }
    end

    def set_current_user_active
      current_user.reload.active = true
      current_user.save
    end

    def update_account_config 
      current_account.account_configuration.contact_info[:email] = @user_email_config[:new_email] if current_account.contact_info[:email] == @user_email_config[:old_email]
      current_account.account_configuration.billing_emails[:invoice_emails] = current_account.account_configuration.invoice_emails.map{|x|x == @user_email_config[:old_email] ? @user_email_config[:new_email] : x}
      current_account.account_configuration.save
    end

    def check_onboarding_finished
      redirect_to '/' unless (current_user.privilege?(:admin_tasks) && current_account.onboarding_pending?) 
    end

    def parse_channel_config
      @channel_config = JSON.parse(params['account_channel_config']).symbolize_keys
    end

    def apply_account_channel_config
      enable_livechat_feature if @channel_config[:chat].present?
      enable_phone_channel if @channel_config[:phone].present?
      [:forums,:social].each { |channel| send("toggle_#{channel}_channel", @channel_config[channel]) }
    end

    def add_to_crm
      #skipping freshsales here since its done in callbacks
      if (Rails.env.production? or Rails.env.staging?)
        Resque.enqueue(Marketo::AddLead, { account_id: current_account.id, 
          signup_id: nil, fs_cookie: nil, skip_freshsales: true  })
      end
    end
end
