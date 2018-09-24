class OnboardingDelegator < BaseDelegator
	validate :validate_domain_name, if: -> { @domain }

	def initialize(record, options = {})
		super(record, options)
		@domain = options[:new_domain]
	end

	def validate_domain_name
		errors[:domain] << :invalid_domain unless DomainGenerator.valid_domain?(@domain)
	end
end