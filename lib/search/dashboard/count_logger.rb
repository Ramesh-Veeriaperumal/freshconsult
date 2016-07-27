class Search::Dashboard::CountLogger < Search::V2::Utils::EsLogger

  def log_path
    @@count_es_log_pth ||= "#{Rails.root}/log/count_es_requests.log"
  end 

  def log_device
    @@count_es_logger ||= Logger.new(log_path)
  end

  def log(message, level='info')
    begin
      log_device.send(level, "[#{@log_uuid}] [#{timestamp}] #{message}")
    rescue Exception => e
      Rails.logger.error("[#{@log_uuid}] Exception in Count ES Logger :: #{e.message}")
      NewRelic::Agent.notice_error(e)
    end
  end
end