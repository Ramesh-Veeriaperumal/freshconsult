class Fluffy::V2ApiWrapper
  include Fluffy::Constants

  def initialize(client)
    @client = client
  end

  def update(domain, account_id, limit, granularity = MINUTE_GRANULARITY, account_paths = [])
    unless domain.present? || limit.present?
      Rails.logger.info 'FLUFFY domain/limit is missing in the params'
      return false
    end
    fluffy_account = Fluffy::AccountV2.new(account_id: account_id,
                                           name: domain,
                                           limit: limit.to_i,
                                           granularity: GRANULARITY_OPTIONS[granularity],
                                           account_paths: account_paths)
    response = self.class.log_response_with_time(:update_application, [domain, fluffy_account]) do
      @client.update_application(domain, fluffy_account)
    end
    success?(response)
  end

  def destroy(domain)
    params = { identifier: Fluffy::Identifier.new }
    response = self.class.log_response_with_time(:delete_account, [domain, params]) do
      @client.delete_account(domain, params)
    end
    success?(response)
  end

  def success?(response)
    self.class.success?(response)
  end

  def create(domain, account_id, limit, granularity = MINUTE_GRANULARITY, account_paths = [])
    unless domain.present? || limit.present?
      Rails.logger.info 'FLUFFY domain/limit is missing in the params'
      return false
    end

    params = { account_v2: Fluffy::AccountV2.new(account_id: account_id,
                                                 name: domain,
                                                 limit: limit.to_i,
                                                 granularity: Fluffy::Constants::GRANULARITY_OPTIONS[granularity],
                                                 account_paths: account_paths) }
    fluffy_add_account(params)
  end

  def fluffy_add_account(params)
    response = self.class.log_response_with_time(:add_application, params) do
      @client.add_application(params)
    end
    success?(response)
  end

  def find_account(domain, product)
    params = { product: product }
    self.class.log_response_with_time(:find_application, params) do
      response = @client.get_account(domain, params)
      success?(response) ? response : nil
    end
  end

  class << self
    def success?(response)
      !(response.is_a?(Hash) && response[:error])
    end

    def log_error(err, method, params, response)
      Fluffy::Error.log(request_info(method, params), err)
      { error: true } if response.nil?
    end

    def log_response_with_time(method, params)
      response = nil
      start_time = Time.zone.now
      begin
        response = yield
      rescue Fluffy::ApiError => e
        response = log_error(e, method, params, response)
      rescue StandardError => e
        response = log_error(e, method, params, response)
      end
      time_taken = (Time.zone.now - start_time)
      Rails.logger.info "FLUFFY API_CALL_INFO request_info=#{request_info(method, params).inspect}, response=#{response.inspect}, response_time=#{time_taken.presence}"
      response
    end

    def request_info(method, params)
      {
        account_id: Account.try(:current).try(:id),
        user_id: User.try(:current).try(:id),
        method: method,
        params: params
      }
    end
  end
end
