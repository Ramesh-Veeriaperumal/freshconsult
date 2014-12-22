module Dynamo::CreateTableMethods

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods

		def create_table
			return if table_exists?

			table_options = default_table_options

			table_options[:key_schema].push(table_key(@range, "RANGE")) if !@range.nil?

			table_options[:local_secondary_indexes] = lsi_definition if @local_secondary_indices.present?

			table = Dynamo::CLIENT.create_table(table_options)

			#wait till table has been created
			wait_for_table_resource(table_name, "CREATING")
		end

		protected
		
			def default_table_options
				{
					:table_name => table_name,
					:attribute_definitions => attribute_definitions_by_keys,
					:key_schema => [table_key(@hash, "HASH")],
					:provisioned_throughput => @provisioned_throughput
				}
			end

			def attribute_definitions_by_keys
				all_keys.map do |key|
					attributes_definition(key)
				end
			end

			def table_key(name, type)
				{ :attribute_name => attributes_definition(name)[:attribute_name], :key_type => type }
			end

			def lsi_definition
				@local_secondary_indices.map do |lsi|
					{
						:index_name => "#{lsi[:name].to_s}_index",
						:key_schema => [table_key(@hash, "HASH"), table_key(lsi, "RANGE")],
						:projection => { :projection_type => "ALL" }
					}
				end
			end
	end
end