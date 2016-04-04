# encoding: utf-8
class RemoteIntegrationsMapping < ActiveRecord::Base
  
  not_sharded
  
  serialize :configs, Hash

 
end