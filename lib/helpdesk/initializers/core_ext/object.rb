class Object 

  require 'set'

  BLACKLIST_METHODS = %w(eval instance_eval send __send__ public_send exit exit! abort system exec fork open sleep spawn syscall ` throw).to_set.freeze
  WARNING_METHODS = %w(raise fail).to_set.freeze
  
  # New method which blacklists some of the riskier methods. To be used instead of .send
  def safe_send(*args, &block)
    if args && args.length > 0
      if WARNING_METHODS.include?(args[0].to_s)
        Rails.logger.error "SecurityError: safe_send called with '#{args[0]}'. Allowing execution. Stack: #{caller}"
      elsif BLACKLIST_METHODS.include?(args[0].to_s)
        Rails.logger.error "SecurityError: safe_send called with '#{args[0]}'. Blocking execution. Stack: #{caller}"
        raise SecurityError
      end
    end
    block_given? ? send(*args, &block) : send(*args)
  end 

end