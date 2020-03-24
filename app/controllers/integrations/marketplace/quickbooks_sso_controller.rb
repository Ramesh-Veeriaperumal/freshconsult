class Integrations::Marketplace::QuickbooksSsoController < Integrations::Marketplace::LoginController
  skip_filter :select_shard, :only => [:open_id, :open_id_complete]
  around_filter :select_shard_marketplace, :only => [:open_id, :open_id_complete]
  skip_before_filter :check_privilege, :verify_authenticity_token, :set_current_account, :check_account_state,
                     :set_time_zone, :check_day_pass_usage, :set_locale, :check_session_timeout, only: [:open_id, :open_id_complete]

  def open_id
    unless valid_quickbook_claim_id?
      render text: 'Invalid claimed_id', status: 400
      return
    end
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

  # claimed_id can be used for SSRF attack. validate if the URL is an expected URL

  def valid_quickbook_claim_id?
    claimed_id = params['openid.claimed_id']
    if claimed_id.present? && UriParser.valid_url?(claimed_id)
      uri = URI.parse(claimed_id)
      return uri.host == Integrations::Quickbooks::Constant::INTUIT_OPEN_ID_HOST
    end
    false
  end
end
