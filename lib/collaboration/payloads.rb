class Collaboration::Payloads
  HK_CLIENT_ID = 'hk'.freeze
  TOKEN_EXPIRY_TIME = 7200 # (in sec) 2 HRS

  def initialize(params = nil)
    @ticket = Account.current.tickets.find_by_display_id(params[:ticket_id]) if params.present? && params[:ticket_id].present?
  end

  def account_payload
    {
      client_id: HK_CLIENT_ID,
      client_account_id: Account.current.id.to_s,
      init_auth_token: acc_auth_token,
      collab_url: CollabConfig['collab_url'],
      rts_url: CollabConfig['rts_url']
    }
  end

  private

    def acc_auth_token(is_server = false)
      JWT.encode({
                   ClientId: HK_CLIENT_ID,
                   ClientAccountId: Account.current.id.to_s,
                   IsServer: (is_server ? '1' : '0'),
                   UserId: User.current.id.to_s,
                   exp: (Time.now.to_i + TOKEN_EXPIRY_TIME)
                 }, CollabConfig['secret_key'])
    end
end
