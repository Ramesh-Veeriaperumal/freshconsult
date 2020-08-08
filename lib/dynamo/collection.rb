class Dynamo::Collection

	attr_reader :count, :last_evaluated_key, :type
	attr :records

	def initialize(response, class_name)
		@type = class_name
		@count = response[:count]
		@last_evaluated_key = response[:last_evaluated_key]

		@records = []
		response[:items].each do |rec| # PRE-RAILS: NEED TO BE VERIFIED, change in aws-sdk v2 reponse
			@records << @type.constantize.new().set(rec)
		end
	end

	def [](i)
		if i.is_a? Integer
			@records[i]
		end
	end

	def to_a
		@records
	end

	def method_missing(meth_name, *args, &block)
		meth_name = meth_name.to_s.chomp('!')
		if @records.respond_to?(meth_name)
			@records.safe_send(meth_name, *args, &block)
		else
			raise NoMethodError
		end
	end

	def respond_to?(attribute, include_private=false)
		super(attribute, include_private=false) || @records.respond_to?(attribute)
	end

end
