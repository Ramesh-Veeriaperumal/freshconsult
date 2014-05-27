# encoding: utf-8
require 'base64'

module Mobihelp::MobihelpHelperMethods

  MHC_SUCCESS=0
  MHC_FAILED=10
  MHC_INVALID_APPCREDS=20

  private

    def validate_credentials
      authKeyEncoded = request.headers["X-FD-Mobihelp-Auth"];
      unless  authKeyEncoded.nil?
        authKey = Base64.decode64(authKeyEncoded)
        app_key = authKey.split(":")[0]
        app_secret = authKey.split(":")[1] 
        if app_key.blank? or app_secret.blank?
          render :json => generate_mh_err_resp(MHC_INVALID_APPCREDS, "Invalid App Credentials.Check Configuration")
          return;
        end
        @mobihelp_app = current_account.mobihelp_apps.find_by_app_key_and_app_secret(app_key, app_secret)
      end
      if @mobihelp_app.nil?
        render :json => generate_mh_err_resp(MHC_INVALID_APPCREDS, "Invalid App Credentials.Check Configuration")
      end
    end

    def save_user(user_params, device_uuid)
      user = User.new(user_params)
      if user.email.blank? # add uuid id to ignore email requirement.
        user.external_id = device_uuid 
      else
        if current_account.features?(:multiple_user_emails)
          user.user_emails.build({:email => user.email, :primary_role => true, :verified => user.active})
        end
      end
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
      add_status_to_message(message, MHC_SUCCESS, "Successfully Registered")
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
      {
        :breadcrumb_count => app_config[:bread_crumbs],
        :debug_log_count => app_config[:debug_log_count],
        :acc_status => current_account.subscription.paid_account?,
        :solution_category => app_config[:solutions],
        :app_review_launch_count => app_config[:app_review_launch_count]
      }
    end
end
