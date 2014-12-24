class Mobihelp::DevicesController < MobihelpController

  include ReadsToSlave

  skip_filter :run_on_slave , :only =>[:register_user]
  before_filter :validate_device_uuid, :only => [:register, :register_user]
  before_filter :load_user, :only => :register_user
  before_filter :validate_user, :only => :register_user

  def register
    render :json => generate_resp_with_config(nil)
  end

  def register_user
    render :json => register_user_to_device()
  end

  def app_config
    render :json => generate_resp_with_config(nil)
  end

  def register_user_to_device # should be called only when the user is creating a ticket
    associated_dvc = @user.mobihelp_devices.find_by_device_uuid(@device_uuid)
    if associated_dvc.nil?
      dvc_assoc = save_device_association(@user, @device_uuid)
    end

    generate_resp_with_config(@user)
  end

  private
    def load_user
      @user = nil
      user_params = params[:user]

      # Check if there is a user already we can use
      # if email is provided lets tie to the same user for history
      unless user_params[:email].blank?
        @user = User.find_by_email(user_params[:email])
      end

      @user = User.find_by_external_id(@device_uuid) if @user.nil? # case when user is registered with no email
      @user = save_user(user_params, @device_uuid) if @user.nil?
    end

    def validate_user
      render :json => generate_mh_err_resp(MOBIHELP_STATUS_CODE_BY_NAME[:MHC_USER_DELETED], MOBIHELP_STATUS_MESSAGE_BY_NAME[:MHC_USER_DELETED]) if @user.deleted? or @user.blocked?
    end
end
