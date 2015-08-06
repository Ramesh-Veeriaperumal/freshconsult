### MULTILINGUAL SOLUTIONS - META READ HACK!!
module Solution::MultipleThroughSetters

	def new(attributes={})
		association_without_meta.new(attributes)
	end

	def <<(*records)
		association_without_meta << records
	end

	define_method("=") do |records|
		association_without_meta = records
	end

	def build(attributes={})
		association_without_meta.build(attributes)
	end

	def create(attributes={})
		association_without_meta.build(attributes)
	end

	def destroy_all
		association_without_meta.destroy_all
	end

	def delete_all
		association_without_meta.destroy_all
	end

	def clear
		association_without_meta.clear
	end

	protected

	def association_name
		proxy_association.reflection.name
	end

	def association_name_without_meta
		association_name.to_s.sub("through_meta", "without_association")
	end

	def association_without_meta
		proxy_association.owner.send(association_name_without_meta)
	end
end