class Fdadmin::UsersController < Fdadmin::DevopsMainController
  around_filter :select_slave_shard, only: :get_user
  before_filter :set_current_account, only: :get_user
  before_filter :load_user_record, only: :get_user

  def get_user
    result = {
      email: @user.email,
      second_email: @user.second_email,
      name: @user.name,
      account_id: @user.account_id,
      language: @user.language,
      time_zone: @user.time_zone,
      phone: @user.phone,
      mobile: @user.mobile,
      twitter_id: @user.twitter_id,
      fb_profile_id: @user.fb_profile_id,
      avatar_url: @user.avatar_url,
      user_id: @user.id
    }
    if @user.agent?
      result[:roles] = @user.roles.map(&:name)
      result[:api_key] = @user.single_access_token
    end
    respond_to do |format|
      format.json do
        render json: result
      end
    end
  end

  def load_user_record
    if params[:user_id] && params[:account_id]
      @user = Account.current.all_users.find_by_id(params[:user_id])
    elsif params[:email] && params[:account_id]
      @user = Account.current.all_users.find_by_email(params[:email])
    elsif params[:uuid] && params[:account_id] && freshid_enabled?
      authorization = Account.current.authorizations.find_by_uid_and_provider(params[:uuid], Freshid::Constants::FRESHID_PROVIDER)
      @user = authorization.user if authorization.present?
    end
    render(json: nil, status: 404) && return if @user.nil?
  end

  def set_current_account
    if params[:account_id]
      account = Account.find(params[:account_id])
      account.make_current if account
    end
    render(json: nil, status: 404) && return if Account.current.nil?
  end

  private

    def freshid_enabled?
      Account.current.freshid_enabled?
    end
end
