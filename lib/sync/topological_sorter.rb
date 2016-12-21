module Sync
  class TopologicalSorter
    include TSort
     
    Job = Struct.new(:model_name, :dependencies)
    def initialize()
      @jobs = Hash.new{|h,k| h[k] = []}
    end
   
    alias_method :sort, :tsort
     
    def add(model_name, dependencies=[])
      @jobs[model_name] = dependencies
    end
     
    def tsort_each_node(&block)
      @jobs.each_key(&block)
    end
     
    def tsort_each_child(node, &block)
      @jobs[node].each(&block) if @jobs.has_key?(node)
    end
  end
end