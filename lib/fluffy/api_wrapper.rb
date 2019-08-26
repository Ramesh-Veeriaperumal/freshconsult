class Fluffy::ApiWrapper

  attr_accessor :domain, :limit, :granularity, :path

  HOUR_GRANULARITY = :hour
  MINUTE_GRANULARITY = :minute
  GRANULARITY_OPTIONS = { hour: 'HOUR', minute: 'MINUTE' }.freeze

  def initialize(domain)
    @domain = domain
  end

  def update(limit, granularity = :hour)
    fluffy_account = Fluffy::Account.new({name: domain, limit: limit, granularity: GRANULARITY_OPTIONS[granularity]})
    response = self.class.log_response_with_time(:update_application, [domain, fluffy_account]) do
      $fluffy_client.update_application(domain, fluffy_account)
    end
    success?(response)
  end

  def destroy
    params = {
      identifier: Fluffy::Identifier.new
    }
    response = self.class.log_response_with_time(:delete_account, [domain, params]) do
      $fluffy_client.delete_account(domain, params)
    end
    success?(response)
  end

  def update_path_limits(limit, path, request_type, granularity = :hour)
    fluffy_account_path = Fluffy::AccountPath.new(:method => request_type, :limit => limit, :path => path, :granularity => GRANULARITY_OPTIONS[granularity])
    fluffy_account = Fluffy::Account.new({name: domain, limit: limit, granularity: GRANULARITY_OPTIONS[granularity], path: fluffy_account_path})

    response = self.class.log_response_with_time(:update_application, [domain, fluffy_account]) do
      $fluffy_client.update_application(domain, fluffy_account)
    end
    success?(response)
  end

  def success?(response)
    self.class.success?(response)
  end

  class << self

    def create(domain, limit, granularity = :hour)
      params = {
        account: Fluffy::Account.new(name: domain, limit: limit, granularity: GRANULARITY_OPTIONS[granularity])
      }
      response = log_response_with_time(:add_application, params) do
        $fluffy_client.add_application(params)
      end
      success?(response)
    end

    def find_by_domain(domain)
      params = {
        name: domain
      }
      log_response_with_time(:find_application, params) do
        $fluffy_client.find_application(params)
      end
    end

    def success?(response)
      !(response.is_a?(Hash) && response[:error])
    end

    def log_error(e, method, params, response)
      Fluffy::Error.log(request_info(method, params), e)
      { error: true } if response.nil?
    end

    def log_response_with_time(method, params)
      response = nil
      start_time = Time.now
      begin
        response = yield
      rescue Fluffy::ApiError => e
        response = log_error(e, method, params, response)
      rescue StandardError => e
        response = log_error(e, method, params, response)
      end
      time_taken = (Time.now - start_time)
      Rails.logger.info "FLUFFY API_CALL_INFO request_info=#{request_info(method, params).inspect}, response=#{response.inspect}, response_time=#{time_taken.presence}"
      response
    rescue StandardError => e
      Rails.logger.info "Error while logging FLUFFY request/response exception=#{e.inspect}, backtrace=#{e.backtrace}"
    end

    def request_info(method, params)
      {
        account_id: Freshid.account_class.try(:current).try(:id),
        user_id: Freshid.user_class.try(:current).try(:id),
        method: method,
        params: params
      }
    end
  end
end