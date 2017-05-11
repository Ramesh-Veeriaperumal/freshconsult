class DomainGenerator

	attr_accessor :email, :email_name, :domain, :subdomain

	include ActiveModel::Validations

	HELPDESK_BASE_DOMAIN = AppConfig['base_domain'][Rails.env]
	DOMAIN_SUGGESTION_KEYWORDS = ["help", "assist", "service", "care", 
		"aid", "relations", "desk", "team"]
	DOMAIN_SUGGESTIONS = DOMAIN_SUGGESTION_KEYWORDS + DOMAIN_SUGGESTION_KEYWORDS.map{|sugg| "-#{sugg}"}

	validates_presence_of :email
	validate :email_validity


	def initialize(email)
		self.email = Mail::Address.new(email)
		Rails.logger.warn "Email not valid" unless self.valid?
	end

	def domain
		@domain ||= generate_helpdesk_domain
		@domain = generate_random_domain_name while @domain.blank?
		@domain
	end

	def email_company_name
		@email_company_name ||= email.domain.split('.').first
	end

	def email_name
		@email_name ||= (email.display_name.try(:downcase) || email.local)
	end

	def subdomain
		@subdomain ||= domain.gsub(".#{HELPDESK_BASE_DOMAIN}", "")
	end

	def self.valid_domain?(full_domain)
		sample_account = Account.new
		sample_account.full_domain = full_domain
		(DomainMapping.new(:domain => full_domain).valid? && 
			sample_account.run_domain_validations)
	end


	private

	def generate_helpdesk_domain
		([""] + DOMAIN_SUGGESTIONS).each do |suggestion|
			current_domain_suggestion = "#{domain_prefix}#{suggestion}.#{HELPDESK_BASE_DOMAIN}"
			return current_domain_suggestion if self.class.valid_domain?(current_domain_suggestion)
		end
		return nil
	end

	def domain_prefix
		@domain_prefix ||= self.send("email_#{domain_prefix_type}")
		@domain_prefix = @domain_prefix.downcase.gsub(/[^0-9a-z]/i, '')
	end

	def domain_prefix_type
		@domain_prefix_type ||= (email_free_or_disposable? ? "name" : "company_name")
	end

	def email_free_or_disposable?
		(Freemail.free?(email_address) || Freemail.disposable?(email_address))
	end

	def email_address
		@email_address ||= email.address
	end	

	def generate_random_domain_name
		current_domain_suggestion = "#{domain_prefix}#{random_digits}.#{HELPDESK_BASE_DOMAIN}"
		return current_domain_suggestion if self.class.valid_domain?(current_domain_suggestion)
	end

	def random_digits
		SecureRandom.random_number.to_s[2..4]
	end

	def email_validity
		unless email_address.match(AccountConstants::EMAIL_VALIDATOR)
			self.errors.add(:email, I18n.t("activerecord.errors.messages.email_invalid"))
		end
	end
end
