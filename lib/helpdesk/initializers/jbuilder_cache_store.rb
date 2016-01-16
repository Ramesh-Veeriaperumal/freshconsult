JbuilderTemplate.class_eval do

  def cache!(key=nil, options={})
    if @context.controller.perform_caching && @context.controller.cache_store

      # Jbuilder uses Rails.cache instead, which is set to file_store by default(not overriden in config files)
      value = @context.controller.cache_store.fetch(_cache_key(key, options), options) do
        _scope { yield self }
      end

      merge! value
    else
      yield
    end
  rescue Dalli::RingError => e
    NewRelic::Agent.notice_error(e)
    Rails.logger.error("API Dalli error: #{e.message}\n#{e.backtrace.join("\n")}")
    yield
  end
end

#Monkey Patch to avoid the conversion of BigDecimal to String while rendering using MultiJson. (Rails bug)
#REF - http://stackoverflow.com/questions/6128794/rails-json-serialization-of-decimal-adds-quotes
class BigDecimal
  def as_json(options = nil)
    #Returns true if the value is a valid IEEE floating point number (it is not infinite, and nan? is false)
      self.to_f if finite?
  end
end