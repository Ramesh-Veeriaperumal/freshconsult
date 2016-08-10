class Admin::ChatWidgetsController < Admin::AdminController

  include ChatHelper
  before_filter { |c| c.requires_feature :chat }

  def index
    if chat_activated?
      @widgets = current_account.chat_widgets
      @chat_enabled = current_account.chat_setting.enabled
      @chat_active = true
    else
      @chat_active = false
    end
  end

  def edit
    @widget = current_account.chat_widgets.find(params[:id])
  end

  def enable
    if params[:product_id].present?
      chat_widget = current_account.chat_widgets.find_by_product_id(params[:product_id])
      product = chat_widget.product
      attributes = {
                     :external_id        => params[:product_id]
                  };
      attributes[:site_url] = product.portal ? product.portal.portal_url : product.account.full_domain
      attributes[:name]     = product.name
      attributes[:language] = product.portal ? product.portal.language : current_account.language
      attributes[:timezone] = current_account.time_zone
      attributes[:active]   = params[:active]

      request_params = { :attributes => attributes }
      response = livechat_request("create_widget", request_params, 'widgets', 'POST')
      if response && response[:status] === 201
        result = JSON.parse(response[:text])
        if result && result['data'] && chat_widget.update_attributes({:active => result['data']['active'], :widget_id => result['data']['widget_id'] })
          render :json => {:status => "success", :result => result['data']}
        else
          render :json => {:status => "error", :message => "Error while creating widget"}
        end
      else
        message = response[:message] ? response[:message] : "Error while creating widget"
        render :json => {:status => "error", :message => message}
      end
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end
  end

  def update
    update_attribs = {}
    site_id = current_account.chat_setting.site_id
    attributes = params[:attributes]
    if attributes.key?("business_calendar_id")
      business_cal_id = attributes[:business_calendar_id]
      update_attribs[:business_calendar_id] = business_cal_id if business_cal_id
      calendar_data  = business_cal_id.blank? ? nil : JSON.parse(BusinessCalendar.find(business_cal_id).to_json({:only => [:time_zone, :business_time_data, :holiday_data]}))['business_calendar']
      attributes[:business_calendar] = calendar_data
    end
    update_attribs[:show_on_portal] = attributes[:show_on_portal] if attributes[:show_on_portal]
    update_attribs[:portal_login_required] = attributes[:portal_login_required] if attributes[:portal_login_required]
    widget = current_account.chat_widgets.find_by_id(params[:id])

    attributes.except!(:business_calendar_id, :show_on_portal, :portal_login_required)
    request_params = { :attributes => attributes}
    response = livechat_request("update_widget", request_params, 'widgets/'+widget.widget_id, 'PUT')

    res = JSON.parse(response[:text])
    if res && res['status'] == "success"
      widget.update_attributes(update_attribs) unless update_attribs.empty?
      render :json => {:status => "success"}
    else
      render :json => {:status => "error", :message => "Record Not Found"}
    end
  end

  def toggle
    app_id = ChatConfig['app_id']
    widget = current_account.chat_widgets.find_by_id(params[:id])
    site_id = widget.chat_setting.site_id
    if widget
      request_params = { :attributes => params[:attributes] }
      response = livechat_request("update_widget", request_params, 'widgets/'+widget.widget_id, 'PUT')
      res = JSON.parse(response[:text])
      if res && res['status'] == "success"
        widget.update_attributes(params[:attributes])
        status = "success"
      else
        status =  "error"
      end
    else
      status = "error"
    end
    render :json => { :status => status }
  end
end
