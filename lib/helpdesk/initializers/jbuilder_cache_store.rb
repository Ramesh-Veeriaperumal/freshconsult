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