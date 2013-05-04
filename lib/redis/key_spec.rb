class Redis::KeySpec
  attr_accessor :key, :options, :template # options & template need to be removed in next deployment
  
  def initialize(template = nil, options_hash = {})
    @key = template
    @options = options_hash # To be removed in next deployment
    if options_hash.is_a?(Hash) && !options_hash.empty?
      if template.nil?
        options_hash.sort_by(&:to_s).each do |key,val|
          @key << ":#{key}:#{val}"
        end
      else
        begin
          @key = template % options_hash
        rescue IndexError => index_error
          Rails.logger.error "Error occured on interpolating Redis::KeySpec #{options_hash.inspect} - #{index_error.message} "
        end
      end
    end
  end

  def to_s
    key
  end
end
