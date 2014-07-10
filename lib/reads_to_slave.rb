module ReadsToSlave
 def self.included(base)
  base.class_eval do
    around_filter :run_on_slave
   end
  end
  
  def run_on_slave(&block)
    Sharding.run_on_slave(&block)
  end 

end