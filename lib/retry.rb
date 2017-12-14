class Retry
  
  RETRY_OPTIONS = {:max_tries => 3, :base_sleep_seconds => 1.0, :rescue => StandardError}
 
  def self.retry_this(options = {})
    options.reverse_merge!(RETRY_OPTIONS)
    max_tries = options[:max_tries]
    base_sleep_seconds = options[:base_sleep_seconds]
    exceptions_to_rescue = Array(options[:rescue])
    attempt_no = 0
    begin
      attempt_no = attempt_no + 1
      yield
    rescue  *exceptions_to_rescue => exception
      raise exception if attempt_no >= max_tries
      sleep_seconds = base_sleep_seconds * (2 ** (attempt_no))
      sleep sleep_seconds
      retry
    end
  end 
end
