class SchedulerService::Utils::LoggerClient

  LOG_FILE_NAME = "scheduler_messages"
  attr_accessor :log_file_name

  def initialize(params = {})
    @log_file_name = LOG_FILE_NAME
  end

  def log_path
    @scheduler_log_path ||= "#{Rails.root}/log/#{log_file_name}.log"
  end 

  def log_device
    @scheduler_logger ||= Logger.new(log_path)
  end

  def log_request(request_uuid, payload=nil, scheduler_type = nil)
    output = []

    output << "request_type = Scheduler Request"
    output << "account_id = #{Account.current.try(:id)}"
    output << "payload = #{payload.inspect}" if payload
    output << "scheduler_type = #{scheduler_type.inspect}" if scheduler_type

    log_msg("uuid=#{request_uuid.inspect}, #{output.join(',')}")
  end

  def log_response(request_uuid, response, scheduler_type = nil, error_msg = nil)
    output = []

    output << "response_type = Scheduler Response"
    output << "[response_code = #{response.code}]"
    output << "(scheduler_type = #{scheduler_type})" if scheduler_type
    output << "(error=#{error_msg})" if error_msg

    log_msg("uuid=#{request_uuid.inspect}, #{output.join(',')}")
  end

  def log_msg(message, level='info')
      log_device.send(level, message)
    rescue Exception => e
      Rails.logger.error("Exception in Scheduler Logger :: #{e.message}")
      NewRelic::Agent.notice_error(e)
  end

  def save_response_information(response, job_id, group)
    if group == ::SchedulerClientKeys['ticket_delete_group_name']
      ticket_id = parse_job_id(job_id)[2]
      trace_id = response.headers[:x_request_id]
      ticket = Account.current.tickets.where(id: ticket_id).first
      ticket && ticket.update_scheduler_trace_id(trace_id)
    end
  end

  private

    def parse_job_id(job_id)
      job_id.split('_')
    end
end
