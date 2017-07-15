class Integrations::Marketplace::QuickbooksSsoController < Integrations::Marketplace::LoginController
  skip_filter :select_shard, :only => [:open_id, :open_id_complete]
  around_filter :select_shard_marketplace, :only => [:open_id, :open_id_complete]
  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account, :set_ui_preference, :check_account_state, 
    :set_time_zone, :check_day_pass_usage, :set_locale, :only => [:open_id, :open_id_complete]

  def open_id
    url = Integrations::Quickbooks::Constant::OPENID_URL
    return_url = integrations_marketplace_quickbooks_sso_open_id_complete_url + "?app=quickbooks"
    if (params[:operation])
      return_url += "&operation=#{params[:operation]}"
    end
    rqrd_data = ["http://axschema.org/contact/email", "http://axschema.org/intuit/realmId", "http://axschema.org/namePerson"]
    authenticate_with_open_id(url,{ :required => rqrd_data, :return_to => return_url }) do |result|
    end
  end

  def open_id_complete
    map_remote_user
  end

  def landing
    installed_app = current_account.installed_applications.with_name('quickbooks').first
    if params['operation'] == 'disconnect' && installed_app.present?
      installed_app.destroy
      flash[:notice] = t(:'flash.application.uninstall.success') if installed_app.destroyed?
      redirect_url = integrations_applications_url
    elsif params['operation'] == 'launch' || installed_app.present?
      redirect_url = "/helpdesk"
    else
      redirect_url = "/auth/quickbooks?origin=id%3D" + current_account.id.to_s
    end
    redirect_to redirect_url
  end

  private

  def select_shard_marketplace(&block)
    if ["open_id_complete"].include?(params[:action])
      fetch_data_from_ax_response
    end
    if @account_id
      Sharding.select_shard_of(@account_id) do
        yield
      end
    else
      yield
    end
  end

  def fetch_data_from_ax_response
    resp = request.env[Rack::OpenID::RESPONSE]
    data = Hash.new
    if resp.status == :success
      ax_response = OpenID::AX::FetchResponse.from_success_response(resp)
      data['email'] = ax_response.data["http://axschema.org/contact/email"].first
      data['remote_id'] = ax_response.data["http://axschema.org/intuit/realmId"].first
      data['user_name'] = ax_response.data["http://axschema.org/namePerson"].first
      data['account_name'] = ''

      if data['email'] && data['remote_id']
        data['user_name'] = '' if data['user_name'] == data['email']
      end
    else
      data['email'] = nil
      data['remote_id'] = nil
    end
    initialize_attr(data)
  end

end
