class SearchServiceResult

	attr_reader :records
	def initialize(options={})
		@records = options["records"]
	end
end