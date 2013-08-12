class Redis::KeySpec
  
  def initialize(key_or_template, options_hash = {})
    @key = key_or_template
    if options_hash.is_a?(Hash) && !options_hash.empty?
      if key_or_template.blank?
        @key = options_hash.sort_by(&:to_s).map{|k,v| "#{k}:#{v}"}.join(':')
      else
        begin
          @key = key_or_template % options_hash
        rescue IndexError => index_error
          Rails.logger.error "Error occured in Redis::KeySpec #{options_hash.inspect} - #{index_error.message} "
          #NewRelic::Agent.notice_error(index_error,{:description => "Error occured in Redis::KeySpec #{options_hash.inspect}"})
        end
      end
    end
  end

  def to_s
    @key
  end
end
