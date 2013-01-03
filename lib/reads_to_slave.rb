module ReadsToSlave
 def self.included(base)
  base.class_eval do
    include SeamlessDatabasePool::ControllerFilter
    use_database_pool :all => :persistent
   end
  end
end