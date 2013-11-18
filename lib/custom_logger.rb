# lib/custom_logger.rb
class CustomLogger < Logger
	
	#overridding format for Logger
  def format_message(severity, timestamp, progname, msg)
    "#{timestamp.to_formatted_s(:db)} #{msg}\n" 
  end
end
 