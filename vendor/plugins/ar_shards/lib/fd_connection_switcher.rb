ActiveRecord::Base.class_eval do 
  
  class << self

  def on_shard(shard, &block)
    old_options = current_shard_selection.options
    switch_connection(:shard => shard) if supports_sharding?
      yield
    ensure
      #switch_connection(old_options)
  end
  
  def on_all_shards(&block)
    old_options = current_shard_selection.options
    if supports_sharding?
    	shard_names.map do |shard|
          switch_connection(:shard => shard)
          yield(shard)
        end
      else
        [yield]
      end
    ensure
      #switch_connection(old_options)
  end
  end
end