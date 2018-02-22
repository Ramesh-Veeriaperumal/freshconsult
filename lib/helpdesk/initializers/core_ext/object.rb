class Object 
 
  BLACKLIST_METHODS = %w(eval instance_eval send __send__ public_send exit system).freeze
  
  # New method which blacklists some of the riskier methods. To be used instead of .send
  def safe_send(*args, &block)
    Rails.logger.debug "Inside safe_send"
    if args && args.length > 0 and BLACKLIST_METHODS.include?(args[0].to_s)
      raise SecurityError
    else
      block_given? ? send(*args, &block) : send(*args)
    end
  end 

end