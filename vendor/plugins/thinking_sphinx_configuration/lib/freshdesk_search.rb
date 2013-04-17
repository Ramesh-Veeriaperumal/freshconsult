ThinkingSphinx::Search.class_eval do
  
  def instances_from_class(klass, matches)
    index_options = klass.sphinx_index_options
    ids = matches.collect { |match| match[:attributes]["sphinx_internal_id"] }
    instances = ::ActiveRecord::Base.on_shard(:shard_1) do
    ::ActiveRecord::Base.on_slave do
      ids.length > 0 ? klass.find(
        :all,
        :joins      => options[:joins],
        :conditions => {klass.primary_key_for_sphinx.to_sym => ids},
        :include    => include_for_class(klass),
        :select     => (options[:select]  || index_options[:select]),
        :order      => (options[:sql_order] || index_options[:sql_order])
      ) : []
      end
      end
      # Raise an exception if we find records in Sphinx but not in the DB, so
      # the search method can retry without them. See 
      # ThinkingSphinx::Search.retry_search_on_stale_index.
      if options[:raise_on_stale] && instances.length < ids.length
        stale_ids = ids - instances.map { |i| i.id }
        raise StaleIdsException, stale_ids
      end

      # if the user has specified an SQL order, return the collection
      # without rearranging it into the Sphinx order
      return instances if (options[:sql_order] || index_options[:sql_order])

      ids.collect { |obj_id|
        instances.detect do |obj|
          obj.primary_key_for_sphinx == obj_id
        end
      }
  end
  def log(message, method = :debug, identifier = 'Sphinx')
    info = ''
    info = "#{identifier}   #{message}"
    RAILS_DEFAULT_LOGGER.send method, info
  end
 

end

