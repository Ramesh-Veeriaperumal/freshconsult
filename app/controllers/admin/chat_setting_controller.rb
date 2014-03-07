class Admin::ChatSettingController < Admin::AdminController

  before_filter { |c| c.requires_feature :chat }
  before_filter  :validate, :only => [:update]

  def index
    if current_account.chat_setting
      @chat = current_account.chat_setting
    else
      @chat = ChatSetting.new
      @chat.save
    end
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
             render :json => {:status => @status , :message => @message}
          }
       end
  end
end