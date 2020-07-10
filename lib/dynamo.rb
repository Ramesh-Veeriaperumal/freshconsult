class Dynamo

	include Dynamo::Callbacks
	include Dynamo::CreateTableMethods
	include Dynamo::QueryMethods
	include Dynamo::Validations
	include Dynamo::FindMethods

	CLIENT = $dynamo_v2_client
	TYPES = [:s, :ss, :n, :ns, :b]

	DATA_TYPE = { :s => "S", :ss => "SS", :n => "N", :ns => "NS", :b => "B"}

	TYPE_CLASS_MAPPING = {
		:n => [Numeric],
		:ns => [Array, Numeric],
		:ss => [Array, String],
		:s => [String]
	}

  DYNAMO_THROUGHPUT = {
    read: 10,
    write: 10,
    inactive: 1
  }.freeze

  DYNAMO_ACTIONS = {
    put: 'PUT',
    add: 'ADD'
  }.freeze

  def self.read_capacity
    DYNAMO_THROUGHPUT[:read]
  end

  def self.write_capacity
    DYNAMO_THROUGHPUT[:write]
  end

  def self.inactive_capacity
    DYNAMO_THROUGHPUT[:inactive]
  end

	def self.hash_key(name, type)
		@hash = { :name => name.to_s, :type => assign_type(type)}
	end

	def self.range(name, type)
		@range = { :name => name.to_s, :type => assign_type(type)}
	end

	def self.local_secondary_index(name, type)
		@local_secondary_indices ||= []
		@local_secondary_indices << { :name => name.to_s, :type => assign_type(type)}
	end

	def self.provisioned_throughput(read, write)
		@provisioned_throughput = { :read_capacity_units => read, :write_capacity_units => write }
	end

	def self.update_throughput(read, write)

		CLIENT.update_table(
			{ 
				:table_name => table_name,
				:provisioned_throughput => {
					:read_capacity_units => read,
					:write_capacity_units => write
				}
			}
		)

		wait_for_table_resource(table_name, "UPDATING")
	end


	def self.build(opts={})
		obj = self.new
		opts.each do |k,v|
			obj[k] = v
		end
		obj
	end

	def set(hash)
		@attributes.clear
		@changes.clear
		hash.each_pair do |k,v|
			@attributes[k] = v
		end
		@dirty = false

		self
	end

	def attributes
		@attributes
	end

	def [](attr)
		@attributes[attr.to_s]
	end

	def []=(attr, value)
		if @attributes[attr.to_s] != value
			@changes[attr.to_s] = {:old => @attributes[attr.to_s], :new => value}
			@dirty = true
		end
		@attributes[attr.to_s] = value
	end

	def changes
		@changes
	end

	def changed?(attr)
		@changes[attr.to_s].present?
	end

	def new_record?
		[@hash, @range].each do |key|
			return true if @attributes[key[:name]].blank? or (@changes[key[:name]].is_a?(Hash) && @changes[key[:name]][:old].blank?)
		end
		false
	end

	def initialize
		duplicate_class_vars

		@attributes, @changes, @errors, @dirty = {}, {}, {}, false

		@attributes[@hash[:name]] = nil
		@attributes[@range[:name]] = nil
	end

	def self.find_or_initialize(opts)
		response = find(opts)
		if response.blank?
			response = name.constantize.new()
			opts.each do |key, value|
				response[key] = value
			end
		end
		response
	end

	def save
		return false unless valid?
		begin
			if new_record?
				CLIENT.put_item(insertion_hash)
			else
				CLIENT.update_item(update_item_options)
			end
			@changes.clear
			true
		rescue Exception => e
			Rails.logger.error "Failed to save #{self.class.table_name} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			false
		end
	end

	def incr!(*attributes)
		return false unless valid? or attributes.blank?
		response = CLIENT.update_item(incr_attributes(1, *attributes))
		response.attributes.empty? ? self : self.set(response[:attributes]) # PRE-RAILS: V1 returns Hash, v2 return response Seahorse::Client::Response. Fails if there is no result.
	end

	def decr!(*attributes)
		return false unless valid? or attributes.blank?
		response = CLIENT.update_item(incr_attributes(-1, *attributes))
		response.attributes.empty? ? self : self.set(response[:attributes]) # PRE-RAILS: V1 returns Hash, v2 return response Seahorse::Client::Response. Fails if there is no result.
	end

	def destroy
		begin
			CLIENT.delete_item({
				:table_name => self.class.table_name,
				:key => primary_key})
			true
		rescue Exception => e
			Rails.logger.error "Error deleting record from dynamo db table #{self.class.table_name} \n#{e.message}\n#{e.backtrace.join("\n\t")}"
			NewRelic::Agent.notice_error(e, {:description => "Error deleting record from dynamo db table #{self.class.table_name}"})
			false
		end
	end

	def self.drop_table
		return unless table_exists?
		begin
			table_data = CLIENT.delete_table(:table_name => table_name)
			wait_for_table_resource(table_name, "DELETING")
		rescue Aws::DynamoDB::Errors::ResourceNotFoundException
			return true
		rescue => e
			return false
		end
	end

	def self.table_exists?
		begin
			table_data = CLIENT.describe_table(:table_name => self.table_name)
			return true
		rescue Aws::DynamoDB::Errors::ResourceNotFoundException
			return false
		end
	end

	def respond_to?(method, include_private = false)
		method = method.to_s.chomp('=').chomp('?')
		if @attributes[method].present?
			true
		else
			super(method, include_private)
		end
	end

	private

	def self.all_keys
		[@hash, @range, *@local_secondary_indices].compact
	end

	def self.default_schema_for_create
		[@hash, @range].compact.map do |key|
		end
	end

	def self.convert(value_hash)
		return value_hash if !value_hash.is_a? Hash
		type, value = value_hash.keys.first, value_hash.values.flatten
		value = numerify(*value) if TYPE_CLASS_MAPPING[type].include?(Numeric)
		TYPE_CLASS_MAPPING[type][1].blank? ? value.first : value
	end

	def self.numerify(*value)
		value.collect {|v| (v.to_f % 1 == 0) ? v.to_i : v.to_f}
	end

	def self.attr_convert(value)
		value_class = value.class
		value_hash = case value_class.to_s
		when "String"
			{ :s => value }
		when "Fixnum"
			{ :n => value.to_s }
		when "Array"
			if value.first.class == Fixnum
				{ :ns => value }
			else
				{ :ss => value }
			end
		end
		convert(value_hash)
	end

	def self.assign_type(type)
		TYPES.include?(type) ? type : TYPES.first
	end

	def self.attributes_definition(key)
		{ :attribute_name => key[:name].to_s, :attribute_type => DATA_TYPE[key[:type]] }
	end

	def self.wait_for_table_resource(name, status)
		table_data = CLIENT.describe_table(:table_name => name)

		while table_data[:table][:table_status] == status
			sleep 1
			table_data = CLIENT.describe_table(:table_name => name)
		end
		true
	end

	def update_item_options
		{
			:table_name => self.class.table_name,
			:key => primary_key,
			:attribute_updates => attribute_updates
		}
	end

	def attribute_updates
		(self.changes.to_a.map do |item|
			{
				item.first.to_s => {
					:value => self.class.attr_convert(item.last[:new].to_s),
					:action => DYNAMO_ACTIONS[:put]
				}
			}
		end).inject {|res, hash| res.merge(hash) }
	end

	def incr_attributes(value, *attributes)
		{
			:table_name => self.class.table_name,
			:key => primary_key,
			:attribute_updates => (attributes.map do |attr|
				{
					attr.to_s => {
						:action => DYNAMO_ACTIONS[:add],
						:value => Dynamo.convert(n: value.to_i)
					}
				}
			end).inject {|res, hash| res.merge(hash) },
			:return_values => 'ALL_NEW'
		}
	end

	def primary_key
		([@hash, @range].map do |key|
			{
				key[:name].to_s => Dynamo.convert(key[:type] => @attributes[key[:name]])
			}
		end).inject { |res, hash| res.merge(hash) }
	end


	def self.indexed_column_names
		@indexed_column_names_val ||= begin
			(([@hash] | [@range] | [*@local_secondary_indices]).map {|i| i[:name] unless i.blank? }) - [[],[nil]]
		end
	end

	def self.indexes
		@index_types_val ||= begin
			Hash[*([@hash] | [@range] | [*@local_secondary_indices]).map{ |k| [k[:name], k[:type]]}.flatten ]
		end
	end

	def self.index_type(index)
		self.indexes[index]
	end

	def self.dynamic_type(value)
		value.is_a?(Numeric) ? :n : :s
	end

	def insertion_hash
		options = {
			:table_name => self.class.table_name,
			:item => item_data_for_insertion,
			:expected => expected_for_insertion
		}
	end

	def item_data_for_insertion
		data = {}
		@attributes.each_pair do |key, value|
			if self.class.indexed_column_names.include?(key)
				data[key] = Dynamo.convert(self.class.indexes[key] => value)
			else
				data[key] = Dynamo.convert(self.class.dynamic_type(value) => value)
			end
		end

		data
	end

	def expected_for_insertion
		expected = self.class.all_keys
		expected = expected - [@range] unless defined?(@range) and @attributes[@range[:name]].present?
		Hash[*(expected.map do |k|
			[k[:name], { :exists => false}]
		end).flatten]
	end

	def method_missing(meth_name, *args, &block)
		last_char = meth_name.to_s.last
		meth_name = meth_name.to_s.chomp('=').chomp('?')
		raise NoMethodError unless @attributes.has_key?(meth_name.to_s) || last_char == '='
		case last_char
		when '?'
			@attributes[meth_name].present?
		when '='
			@attributes[meth_name.to_s] = args.first
			@dirty = true
			args.first
		else
			@attributes[meth_name]
		end
	end

	def duplicate_class_vars
		(self.class.instance_variables - [:"@inheritable_attributes"]).each do |var|
			var = var.to_s.delete('@')
			self.instance_variable_set("@#{var}", self.class.instance_variable_get("@#{var}"))
		end
	end
end