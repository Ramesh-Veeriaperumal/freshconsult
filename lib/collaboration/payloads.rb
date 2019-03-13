class Collaboration::Payloads
  include Redis::RedisKeys
  include Redis::OthersRedis

  HK_CLIENT_ID = 'hk'.freeze
  TOKEN_EXPIRY_TIME = 1_296_000 # (in sec) 15 DAYS

  def initialize(params = nil)
    @ticket = Account.current.tickets.find_by_display_id(params[:ticket_id]) if params.present? && params[:ticket_id].present?
  end

  def account_payload
    payload = {
      client_id: HK_CLIENT_ID,
      client_account_id: Account.current.id.to_s,
      init_auth_token: acc_auth_token,
      rts_url: CollabConfig['rts_url'],
      freshconnect_enabled: freshid_and_freshconnect_enabled?
    }
    payload.merge(payload_params)
  end

  private

    def acc_auth_token(is_server = false)
      JWT.encode(auth_token_payload(is_server), CollabConfig['secret_key'])
    end

    def auth_token_payload(is_server)
      token = {
        ClientId: HK_CLIENT_ID,
        ClientAccountId: current_account.id.to_s,
        IsServer: (is_server ? '1' : '0'),
        UserId: User.current.id.to_s,
        exp: (Time.now.to_i + TOKEN_EXPIRY_TIME)
      }
      if freshid_and_freshconnect_enabled?
        uuid = User.current.freshid_authorization.uid
        freshconnect_params = { UserUUID: uuid, ProductAccountId: current_account.freshconnect_account.product_account_id }
        token.merge!(freshconnect_params)
      end
      token
    end

    def current_account
      Account.current
    end

    def freshid_and_freshconnect_enabled?
      current_account.freshid_enabled? && User.current.freshid_authorization && current_account.freshconnect_enabled?
    end

    def payload_params
      if freshid_and_freshconnect_enabled?
        { collab_url: CollabConfig['freshconnect_url'], product_name: CollabConfig['product_name'] }
      else
        { collab_url: CollabConfig['collab_url'] }
      end
    end
end
