class JbuilderTemplate < Jbuilder

  def cache!(key=nil, options={})
    if @context.controller.perform_caching

      # Jbuilder uses Rails.cache instead, which is set to file_store by default(not overriden in config files)
      value = @context.controller.cache_store.fetch(_cache_key(key, options), options) do
        _scope { yield self }
      end

      merge! value
    else
      yield
    end
  end
end