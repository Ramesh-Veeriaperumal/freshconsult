class Vault::Client
  SUCCESS = [204].freeze
  DEFAULT_TIMEOUT = 10

  def initialize(url, method, token, timeout = DEFAULT_TIMEOUT)
    @url = url
    @method = method
    @account = Account.current
    @headers = headers(token)
    @timeout = timeout
  end

  def update_account(payload = nil)
    response_code = execute(payload)
    SUCCESS.include?(response_code) && !@account.pci_compliance_field_enabled? && @account.add_feature(:pci_compliance_field)
  end

  def delete_account
    execute
    @account.pci_compliance_field_enabled? && @account.revoke_feature(:pci_compliance_field)
  end

  private

    def params(payload = nil)
      {
        method: @method,
        url: @url,
        headers: @headers,
        timeout: @timeout
      }.merge(payload.present? ? { payload: payload } : {})
    end

    def headers(token)
      {
        'X-PRODUCT-NAME' => PciConstants::ISSUER,
        'X-ACCOUNT-ID' => @account.id,
        'Authorization' => token,
        'X-POD-NAME' => PodConfig['CURRENT_POD']
      }
    end

    def execute(payload = nil)
      response = RestClient::Request.execute(params(payload))
      response.code
    rescue StandardError => e
      Rails.logger.error "Failed update with vault_service for AccountId #{@account.id} URL:#{@url} METHOD: #{@method} #{e.inspect}"
      403
    end
end
