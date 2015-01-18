class Workers::Import::CompaniesImport

	extend Resque::AroundPerform

	@queue = "companyImport"

	def self.perform(company_params)
		Workers::Import::CustomersImportWorker.new(company_params).perform
	end
end