class DomainGenerator

	attr_accessor :email, :email_name, :domain, :subdomain, :excluded_domains, :signup_mode

	include ActiveModel::Validations

	HELPDESK_BASE_DOMAIN = AppConfig['base_domain'][Rails.env]
	DOMAIN_SUGGESTION_KEYWORDS = ["help", "assist", "service", "care",
		"aid", "relations", "desk", "team"]
	DOMAIN_SUGGESTIONS = DOMAIN_SUGGESTION_KEYWORDS + DOMAIN_SUGGESTION_KEYWORDS.map{|sugg| "-#{sugg}"}
  ANONYMOUS_DOMAIN = 'demo'.freeze
  ANONYMOUS_SIGNUP = 'anonymous_signup'.freeze

	validates_presence_of :email
	validate :email_validity
	validate :disposable_email?

  def initialize(email, excluded_domains = [], signup_mode = nil)
    self.email = Mail::Address.new(email)
    self.excluded_domains = excluded_domains
    Rails.logger.warn 'Email not valid' unless valid?
    self.signup_mode = signup_mode
  end

  def domain
    if signup_mode == ANONYMOUS_SIGNUP
      @domain ||= generate_demo_domain while @domain.blank?
    else
      @domain ||= generate_helpdesk_domain
      @domain = generate_random_domain_name while @domain.blank?
    end
    @domain = ENV['SQUAD_ACCOUNT_SIGNUP_PREFIX']+@domain if !Rails.env.production? && ENV['SQUAD_ACCOUNT_SIGNUP_PREFIX'] != nil
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
		(domain_exists?(full_domain) && sample_account.run_domain_validations)
	end

	def valid_domain?(full_domain)
		sample_account = Account.new
		sample_account.full_domain = full_domain
		!excluded_domains.include?(full_domain) && (DomainGenerator.domain_exists?(full_domain) &&
			sample_account.run_domain_validations)
	end

	def domain_name
		@domain_name ||= domain_prefix.capitalize
	end

	def self.sample(email, count=1)
		sample_domains = []
		excluded_domains = []
		count.times do
			current_sample_domain = new(email, excluded_domains)
			sample_domains << current_sample_domain.subdomain
			excluded_domains << current_sample_domain.domain
		end
		sample_domains
	end

  def self.domain_exists?(full_domain)
    if Fdadmin::APICalls.non_global_pods?
      find_in_global_pod(full_domain).blank?
    else
      DomainMapping.new(domain: full_domain).valid?
    end
  end

  def self.find_in_global_pod(full_domain)
    request_parameters = {
      new_domain: full_domain,
      target_method: :check_domain_availability
    }
    JSON.parse(Fdadmin::APICalls.connect_main_pod(request_parameters).body)['account_id']
  rescue StandardError => e
    Rails.logger.error "Message: #{e.message} :::: #{e.backtrace.join('\n')}"
    true
  end

	private

	def generate_helpdesk_domain
      ([''] + DOMAIN_SUGGESTIONS).each do |suggestion|
        current_domain_suggestion = "#{domain_prefix}#{suggestion}.#{HELPDESK_BASE_DOMAIN}"
        current_domain_prefix = current_domain_suggestion.split('.')[0]
        return current_domain_suggestion if valid_domain?(current_domain_suggestion) && !Account::RESERVED_DOMAINS.include?(current_domain_prefix)
      end
      nil
    end

	def domain_prefix
		@domain_prefix ||= self.safe_send("email_#{domain_prefix_type}")
		@domain_prefix = @domain_prefix.downcase.gsub(/[^0-9a-z]/i, '')
	end

	def domain_prefix_type
		@domain_prefix_type ||= (email_free? ? "name" : "company_name")
	end

	def email_free?
		Freemail.free?(email_address)
	end

	def email_address
		@email_address ||= email.address
	end

	def generate_random_domain_name
		suggestion_keyword = DOMAIN_SUGGESTIONS.sample
		current_domain_suggestion = "#{domain_prefix}#{suggestion_keyword}#{random_digits}.#{HELPDESK_BASE_DOMAIN}"
		return current_domain_suggestion if valid_domain?(current_domain_suggestion)
	end

	def random_digits
		SecureRandom.random_number.to_s[2..4]
	end

    def generate_demo_domain
      demo_domain = generate_default_demo_domain
      demo_domain = generate_random_demo_domain while demo_domain.blank?
      demo_domain
    end

    def generate_default_demo_domain
      current_time = (Time.now.utc.to_f * 1000).to_i
      domain_suggestion = "#{ANONYMOUS_DOMAIN}#{current_time}.#{HELPDESK_BASE_DOMAIN}"
      return domain_suggestion if valid_domain?(domain_suggestion)
    end

    def generate_random_demo_domain
      current_time = (Time.now.utc.to_f * 1000).to_i
      DOMAIN_SUGGESTIONS.each do |suggestion|
        current_domain_suggestion = "#{ANONYMOUS_DOMAIN}#{suggestion}#{current_time}.#{HELPDESK_BASE_DOMAIN}"
        return current_domain_suggestion if valid_domain?(current_domain_suggestion)
      end
      nil
    end

	# validations
	def email_validity
		unless email_address.match(AccountConstants::EMAIL_VALIDATOR)
			self.errors.add(:email, I18n.t("activerecord.errors.messages.email_invalid"))
		end
	end

	def disposable_email?
		self.errors.add(:email, I18n.t("activerecord.errors.messages.email_disposable")) if Freemail.disposable?(email_address)
	end
end
