class SchedulerService::Client
  ######################################################################################################
  # README
  # This class schedules a job to scheduler service. The end point is taken from scheduler_client.yml
  # Method:: POST/DELETE
  # GROUP:: group name we want to specify. A categorization at their end to add more workers if needed
  # URL: endpoint - should be from a recipe file having different endpoints for staging/prod
  # scheduled_time - this is the iso timestring at which the job will be posted to us
  # payload - the json which will come back to us as args at scheduled time
  # sqs url - the sqs endpoint to which the job comes in with payload at given time
  # log_request - use this method to log the request with uuid and payload in separate file
  # log_response - use this method to log scheduler response with code
  # payload - Please make sure payload doesnt contain PII info like email, pass, name, etc as central is
  # in single region across pods and we need to abide by compliance
  ######################################################################################################

  attr_accessor :job_id, :payload, :account_id, :uuid, :end_point, :scheduler_type, :logger, :group

  def initialize(params = {})
    @job_id         = params[:job_id]
    @payload        = params[:payload] || {}
    @end_point      = params[:end_point]
    @group          = params[:group]
    @account_id     = params[:account_id] || Account.current.try(:id)
    @uuid           = Thread.current[:message_uuid]
    @logger         = SchedulerService::Utils::LoggerClient.new()
    @scheduler_type = params[:scheduler_type] || ''
  end

  def schedule_job
    begin
      scheduler_request = RestClient::Request.new(
        method: :post,
        group: group,
        url: end_point,
        scheduled_time: payload[:scheduled_time].to_s,
        payload: payload.to_json,
        headers: {
          'service' => ::SchedulerClientKeys['token'],
          'content-type' => :json,
          'accept' => :json
        }
      )
      scheduler_response = scheduler_request.execute
      logger.save_response_information(scheduler_response, job_id, group)
      logger.log_request(uuid, payload.to_json, scheduler_type)
      logger.log_response(uuid, scheduler_response, scheduler_type)
      scheduler_response
    rescue RestClient::BadRequest => e
      raise SchedulerService::Errors::BadRequestException.new(e.message)
    rescue RestClient::GatewayTimeout => ex
      raise SchedulerService::Errors::GatewayTimeoutException.new(ex.message)
    end
  end

  def cancel_job
    begin
      scheduler_request = RestClient::Request.new(
        method: :delete,
        url: end_point,
        headers: {
          'service' => ::SchedulerClientKeys['token'],
          'content-type' => :json,
          'accept' => :json
        }
      )
      scheduler_response = scheduler_request.execute
      logger.save_response_information(scheduler_response, job_id, group)
      logger.log_request(uuid, end_point.to_json, scheduler_type)
      logger.log_response(uuid, scheduler_response, scheduler_type)
      scheduler_response
    rescue RestClient::BadRequest => e
      raise SchedulerService::Errors::BadRequestException.new(e.message)
    rescue RestClient::GatewayTimeout => ex
      raise SchedulerService::Errors::GatewayTimeoutException.new(ex.message) 
    end
  end
end
