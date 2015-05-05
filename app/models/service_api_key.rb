# encoding: utf-8
class ServiceApiKey < ActiveRecord::Base
	
  not_sharded

  attr_accessible :api_key, :service_name

  validates_uniqueness_of :service_name, :message => "Application Name Already in use"
  validates_uniqueness_of :api_key, :message => "API Key Already in use"

end
