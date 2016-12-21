module Solution::MarshalDumpMethods

	def marshal_dump
		# Caching only the attributes that are required in the corresponding drop
		self.attributes.slice(*self.class::PORTAL_CACHEABLE_ATTRIBUTES).merge(custom_portal_cache_attributes)
	end

	def marshal_load(data)
		send :initialize, data.slice(*self.class.column_names), :without_protection => true
		# Without the following, associations are not getting loaded
		self.instance_variable_set("@new_record", false)
		data.except(*self.class.column_names).each do |attribute, value|
			# Done this way as self[attribute]= was throwing a warning for every virtual attribute.
			self.instance_variable_get("@attributes")[attribute.to_s] = value
			self.instance_variable_set("@#{attribute.to_s}", value)
		end
	end
end