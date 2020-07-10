module Dynamo::FindMethods

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods

		def find(opts)
			response = Dynamo::CLIENT.get_item(build_find_query_options(opts))
			response.item.blank? ? nil : name.constantize.new.set(response[:item]) # PRE-RAILS: V1 returns Hash, v2 return response Seahorse::Client::Response. Fails if there is no result.
		end

		protected

			def build_find_query_options(opts)
				{
					:table_name => table_name,
					:key => [@hash, @range].compact.map { |key| key_value(opts, key) }.inject(&:merge),
					:consistent_read => true,
					:attributes_to_get => opts[:select]
				}.delete_if { |k, v| v.blank? }
			end

			def key_value(opts, key)
				{
					key[:name].to_s => Dynamo.convert(key[:type] => opts[key[:name].to_sym].to_s)
				}
			end
	end
end