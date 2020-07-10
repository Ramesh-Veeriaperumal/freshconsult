module Dynamo::QueryMethods

	COMPARATOR = { :eq => "EQ", :le => "LE", :lt => "LT", :ge => "GE", :gt => "GT",
								:begins_with => "BEGINS_WITH", :between => "BETWEEN" }

	LIMIT = 10
	SORT_TYPE = false

	def self.included(base)
		base.extend(ClassMethods)
	end

	module ClassMethods
	
		# Query structure :
		# ClassName.query(
			# 	:hash_key => "1", //Operator defaults to Eq
			# 	:hash_key => [:ge, "1"],
			# 	:range_key => [:between, "1", "2"] **,
			# 	:select => [array of string of field names] **,
			# 	:limit => 10 **,
			# 	:ascending => true **
			# )
			# 	** optional

		def query(opts)
			query_options = default_options(opts).merge(select_conditions(opts[:select]))

			merge_conditions(all_keys, query_options, opts)
			use_lsi_indexes(query_options, opts)

			Dynamo::Collection.new(Dynamo::CLIENT.query(query_options), name)
		end

		protected

			def default_options(opts)
				{
					:table_name         => table_name,
					:limit              => opts[:limit] || LIMIT,
					:scan_index_forward => opts[:ascending] || SORT_TYPE,
					:exclusive_start_key => opts[:last_record]
				}.delete_if { |k, v| v.nil? }
			end

			def select_conditions(select)
				return {} if select.blank?
				{
					:select => "SPECIFIC_ATTRIBUTES",
					:attributes_to_get => select
				}
			end

			def merge_conditions(keys, query_options, opts)
				keys.each do |key|
					query_options[:key_conditions] = (query_options[:key_conditions] || {}).merge({
						key[:name].to_s => key_conditions(key, *opts[key[:name].to_sym])
					}) if opts[key[:name].to_sym]
				end
			end

			def use_lsi_indexes(query_options, opts)
				@local_secondary_indices.each do |lsi|
					query_options[:index_name] = "#{lsi[:name]}_index" if opts[lsi[:name].to_sym]
				end
			end

			def key_conditions(key, *value)
				comparator = COMPARATOR.fetch(value[0], COMPARATOR.values.first)
				value.delete(value[0]) if value.length > 1
				{
					:comparison_operator => comparator,
					:attribute_value_list => value.map { |val| Dynamo.convert(key[:type] => val) }
				}
			end
	end
end