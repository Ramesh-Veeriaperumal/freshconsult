ActiveRecord::Migrator.class_eval do
  class << self
    [:up, :down, :run].each do |m|
      define_method("#{m}_with_sharding") do |*args|
        ActiveRecord::Base.on_all_shards do
          self.send("#{m}_without_sharding", *args)
        end
        ActiveRecord::Base.on_shard(nil) do
          self.send("#{m}_without_sharding", *args)
        end
      end
      alias_method m.to_sym, "#{m}_without_sharding".to_sym
      alias_method_chain m.to_sym, :sharding
    end
end
end