# encoding: utf-8
require 'base64'

module Mobihelp::MobihelpHelperMethods
  
  include Cache::Memcache::Mobihelp::App

  MOBIHELP_STATUS = [
    [:MHC_SUCCESS, 0, "Successfully Registered"],
    [:MHC_FAILED, 10, "Registration failed"],
    [:MHC_INVALID_APPCREDS, 20, "Invalid App Credentials. Check Configuration"],
    [:MHC_APP_DELETED, 30, "Mobihelp App has been deleted"],
    [:MHC_DUPLICATE_DEVICE_ID, 40, "Device id should be unique"]
  ]
  MOBIHELP_STATUS_CODE_BY_NAME = Hash[*MOBIHELP_STATUS.map{ |s| [s[0], s[1]] }.flatten]
  MOBIHELP_STATUS_MESSAGE_BY_NAME = Hash[*MOBIHELP_STATUS.map{ |s| [s[0], s[2]] }.flatten]

  private

    def validate_credentials
      authKeyEncoded = request.headers["X-FD-Mobihelp-Auth"];
      unless  authKeyEncoded.nil?
        authKey = Base64.decode64(authKeyEncoded)
        app_key = authKey.split(":")[0]
        app_secret = authKey.split(":")[1] 
        if app_key.blank? or app_secret.blank?
          render :json => generate_mh_err_resp(MOBIHELP_STATUS_CODE_BY_NAME[:MHC_INVALID_APPCREDS], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_INVALID_APPCREDS])
          return;
        end
        @mobihelp_app = fetch_app_from_cache(current_account, app_key)
      end
      if @mobihelp_app.nil? or (@mobihelp_app.app_secret != app_secret)
        render :json => generate_mh_err_resp(MOBIHELP_STATUS_CODE_BY_NAME[:MHC_INVALID_APPCREDS], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_INVALID_APPCREDS])
      elsif @mobihelp_app.deleted
        render :json => generate_mh_err_resp(MOBIHELP_STATUS_CODE_BY_NAME[:MHC_APP_DELETED], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_APP_DELETED])
      end
    end

    def save_user(user_params, device_uuid)
      user = User.new(user_params)
      user.external_id = device_uuid if user.email.blank? # add uuid id to ignore email requirement.
      user.save
      user
    end

    def save_device_association(user, device_uuid)
      user.mobihelp_devices.create({
        :app_id => @mobihelp_app.id,
        :device_uuid => device_uuid
      })
    end

    def generate_resp_with_config(user)
      message = { :config =>  generate_mobile_config }
      message[:api_key]  = user.single_access_token unless user.nil?
      add_status_to_message(message, MOBIHELP_STATUS_CODE_BY_NAME[:MHC_SUCCESS], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_SUCCESS])
    end

    def generate_mh_err_resp(status_code, status_message)
      add_status_to_message({}, status_code, status_message)
    end

    def add_status_to_message(message, status_code, status_message)
      message = {} if message.nil?
      message[:status_code] = status_code
      message[:status] = status_message
      message
    end

    def generate_mobile_config
      app_config = @mobihelp_app.config
      config = {
        :breadcrumb_count => app_config[:bread_crumbs],
        :debug_log_count => app_config[:debug_log_count],
        :solution_category => app_config[:solutions],
        :app_review_launch_count => app_config[:app_review_launch_count],
        :acc_status => current_account.subscription.paid_account?
      }
      config[:app_store_id] = app_config[:app_store_id] if @mobihelp_app.platform == Mobihelp::App::PLATFORM_ID_BY_KEY[:ios]
      config
    end

    def validate_device_uuid
      device_params = params[:device_info]
      @device_uuid = device_params[:device_uuid]
      device = Mobihelp::Device.find_by_device_uuid(@device_uuid)

      if device
        render :json => generate_mh_err_resp(MOBIHELP_STATUS_CODE_BY_NAME[:MHC_DUPLICATE_DEVICE_ID], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_DUPLICATE_DEVICE_ID])
      end
    end
end
