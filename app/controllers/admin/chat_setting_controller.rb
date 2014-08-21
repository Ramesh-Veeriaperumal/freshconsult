class Admin::ChatSettingController < Admin::AdminController

  include ChatHelper
  before_filter(:only => [:toggle, :update]) { |c| c.requires_feature :chat }
  before_filter  :validate, :only => [:update]

  def index
    unless feature?(:chat)
      if is_chat_plan?
        render :request_page
      else
        render_404
      end
    else
      if current_account.chat_setting
        @chat = current_account.chat_setting
      else
        @chat = ChatSetting.new
        @chat.save
      end
    end
  end

  def request_freshchat_feature
    email_params = {
      :subject => t('freshchat.feature_request.email_subject',
                              {:account_name => current_account.name}),
      :recipients => ChatConfig['freshchat_request']['to'][Rails.env],
      :from => current_user.email,
      :cc => current_account.admin_email,
      :message => "A customer with the following account URL has requested for Freshchat"
    }
    FreshchatNotifier.send_later(:freshchat_email_template, current_account, email_params)
    render :json => { :status => :success }
  end 

  def toggle
    if feature?(:chat_enable)
      current_account.features.chat_enable.destroy
    else
      current_account.features.chat_enable.create
    end
    current_account.reload
    respond_to do |format|
      format.js { 
        render :partial => '/admin/chat_setting/toggle.rjs'
      }
    end
  end

  def update
    @chat = current_account.chat_setting || ChatSetting.new

      if @chat.update_attributes(params[:chat_setting])
      	@chat.save
        @business_calendar = @chat.business_calendar
      	@status = "success"
        render_result
      else
      	@status = "error"
        render_result
    	end
  end

  private

  def validate
    if params[:chat_setting][:preferences]
      @message = []
      chat_params = params[:chat_setting][:preferences]
      offset_value_check = chat_params[:window_offset].match(/^\d+$/).blank? || chat_params[:window_offset].to_i > 500
      color_value_check = chat_params[:window_color].match(/^#[0-9a-f]{3}([0-9a-f]{3})?$/i).blank? 
      @message << t(:'freshchat.valid_code') if color_value_check
      @message << t(:'freshchat.window_offset_error_msg') if offset_value_check
      if @message.length > 0
       @status = "error"
       render_result
      end
    end
  end

  def render_result
       respond_to do |format|
          format.json{
            render :json => {:status => @status ,:message => @message, :setting => freshchat_setting}
          }
       end
  end
end