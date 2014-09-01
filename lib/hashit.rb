# encoding: utf-8
class Hashit
	# Useful for converting a has object to a ruby class
	def initialize(hash)
		hash.each do |k,v|
		  self.instance_variable_set("@#{k}", v)  ## create and initialize an instance variable for this key/value pair
		  self.class.send(:define_method, k, proc{self.instance_variable_get("@#{k}")})  ## create the getter that returns the instance variable
		  self.class.send(:define_method, "#{k}=", proc{|v| self.instance_variable_set("@#{k}", v)})  ## create the setter that sets the instance variable
		end
	end
	
	def save
	    hash_to_return = {}
	    self.instance_variables.each do |var|
	      hash_to_return[var.gsub("@","")] = self.instance_variable_get(var)
	    end
	    return hash_to_return
	end
end