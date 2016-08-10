# encoding: utf-8
class RemoteIntegrationsMapping < ActiveRecord::Base
  
  not_sharded
  
  serialize :configs, Hash

  def as_json(options = {})
  	exclude = [:created_at,:updated_at,:id]
		options[:except] = self.configs.empty? ? exclude << :configs : exclude
  	super(options)
	end

    
	def remove_from_global_pod(args={})
  	PodDnsUpdate.perform_async({:remote_id => remote_id,:target_method => :remove_remote_integration_mapping}.merge(args)) if Fdadmin::APICalls.non_global_pods?
  end
 
end