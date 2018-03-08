class Retry
  
  RETRY_OPTIONS = {:max_tries => 3, :rescue => StandardError}
 
  def self.retry_this(options = {})
    options.reverse_merge!(RETRY_OPTIONS)
    max_tries = options[:max_tries]
    exceptions_to_rescue = Array(options[:rescue])
    attempt_no = 0
    begin
      attempt_no = attempt_no + 1
      yield
    rescue  *exceptions_to_rescue => exception
      raise exception if attempt_no >= max_tries
      retry
    end
  end 
end
