class Admin::OnboardingController < Admin::AdminController
  include Onboarding::OnboardingHelperMethods
  include Onboarding::AccountChannels
  include ChatHelper

  before_filter :set_user_email_config, :only => [:update_activation_email]
  before_filter :check_onboarding_finished, only: [:update_channel_configs]
  before_filter :parse_channel_config, only: [:update_channel_configs]
  before_filter :validate_step, :only => [:complete_step]

  def update_activation_email
    current_user.email = @user_email_config[:new_email]
    current_user.keep_user_active = true
    # Add new email & combo to dynamo db and Remove the old combo.
    AccountInfoToDynamo.new().add_account_info_to_dynamo @user_email_config[:new_email], current_user.account_id, current_user.account.created_at.getutc
    AccountInfoToDynamo.new().remove_account_info_to_dynamo @user_email_config[:old_email], current_user.account_id, current_user.account.created_at.getutc
    AccountInfoToDynamo.new().check_associated_account_count @user_email_config[:new_email]
    if current_user.save
      update_account_config
    end
  end

  def resend_activation_email
    current_user.enqueue_activation_email
    render json: {result: true}
  end

  def update_channel_configs
    apply_account_channel_config
    complete_admin_onboarding
    render json: {result: true}
  end

  def complete_step
    step_name = params[:step]
    if current_account.respond_to?("#{step_name}_setup?") && !current_account.send("#{step_name}_setup?")
      current_account.try("mark_#{step_name}_setup_and_save")
    end
    render json: {success: true}
  end

  private
    def set_user_email_config
      @user_email_config = {
        old_email: current_user.email,
        new_email: params["admin_email_update"]["email"]
      }
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
      # enable_phone_channel if @channel_config[:phone].present?
      [:forums,:social].each { |channel| safe_send("toggle_#{channel}_channel", @channel_config[channel]) }
    end

    def validate_step
      render json: {success: false}, status: 400 unless Account::SETUP_KEYS.include?(params[:step].to_s)
    end

end
