class PasswordPolicy < ActiveRecord::Base
  self.primary_key = :id

	belongs_to_account

	include PasswordPolicies::Configs
	include FDPasswordPolicy::Constants
	include Redis::RedisKeys
	include Redis::OthersRedis

	serialize :configs, Hash

	validates_presence_of :policies
	validate :validate_configs

	after_commit ->(obj) { obj.update_password_expiry }, on: :create, :unless => :signup
	after_commit ->(obj) { obj.update_password_expiry }, on: :update, :if => :password_policies_changed
	after_commit :clear_password_policy_cache

	attr_accessor :signup

	USER_TYPE = {
	  :contact => 1,
	  :agent    => 2
	}

	def policies=(policy_data=[])
		policy_data = policy_data.collect{ |p| p.to_sym unless p.blank? }.compact
		write_attribute(:policies, (policy_data & POLICIES_BY_NAME).map { |policy| 2**PASSWORD_POLICIES[policy] }.sum)
	end	

	def policies
		(POLICIES_BY_NAME.select { |policy| is_policy? policy })
	end

	def is_policy?(policy)
		return false if PASSWORD_POLICIES[policy].nil?
		read_attribute(:policies) && (!(read_attribute(:policies).to_i & 2**PASSWORD_POLICIES[policy]).zero?)
	end

	def password_length_enabled?
		is_policy? :minimum_characters
	end

	def password_contains_login_enabled?
		is_policy? :cannot_contain_user_name
	end

	def password_history_enabled?
		is_policy? :cannot_be_same_as_past_passwords
	end

	def password_expiry_enabled?
		is_policy? :password_expiry
	end

	def periodic_login_enabled?
		is_policy? :session_expiry
	end

	def password_alphanumeric_enabled?
		is_policy? :atleast_an_alphabet_and_number	
	end

	def password_mixed_case_enabled?
		is_policy? :have_mixed_case
	end

	def password_special_character_enabled?
		is_policy? :have_special_character
	end
	
	def default_policy? 
		DEFAULT_PASSWORD_POLICIES.sort == self.policies.sort && DEFAULT_CONFIGS == self.configs
	end

	def advanced_policy?
		!default_policy?
	end

	def minimum_character_values
		("8".."99").to_a
	end

	def password_history_match_values
		("1".."5").to_a
	end

	def password_expiry_days_values
		((1..6).to_a.collect{ |x| (x*30).to_s }) << NEVER
	end

	def session_expiry_days_values
		([7, 15, 30, 60, 90].collect{ |x| x.to_s })
	end

	def update_password_expiry
		unless get_others_redis_key(password_expiry_key)
			last_date = (Time.now.utc + GRACE_PERIOD).to_s
			PasswordExpiryWorker.perform_at(4.hours.from_now, {:account_id => self.account.id, :user_type => self.user_type, :last_date => last_date })
			set_others_redis_key(password_expiry_key, GRACE_PERIOD.from_now.to_s)
		end
	end

	def clear_password_policy_cache
		if self.user_type == USER_TYPE[:contact]
			self.account.clear_contact_password_policy_from_cache
		elsif self.user_type == USER_TYPE[:agent]
			self.account.clear_agent_password_policy_from_cache
		end
	end

	def password_expiry_key
		UPDATE_PASSWORD_EXPIRY % { :account_id => self.account.id, :user_type => self.user_type }
	end

	def generate_password
	  base_password = SecureRandom.base64(User::PASSWORD_LENGTH)
	  self.policies.collect do |policy|
	  	configs = self.configs
	  	case policy
	  	when :minimum_characters
	  		length = configs["minimum_characters"].to_i - base_password.length
	  		base_password += SecureRandom.base64(length) if length > 0
	  	when :atleast_an_alphabet_and_number
		  	charset = Array('A'..'Z') + Array('a'..'z')
		  	base_password += charset.sample
	  		base_password += rand(0...9).to_s
	  	when :have_mixed_case
	  		base_password += Array('A'..'Z').sample
	  		base_password += Array('a'..'z').sample
	  	when :have_special_character
	  		base_password += ['!','$','@','%'].sample
	  	end
	  end
	  return base_password.split("").shuffle.join
	end

	def reset_policies
		self.tap do |password_policy|
			password_policy.configs = {}
			password_policy.policies = DEFAULT_PASSWORD_POLICIES
		end
	end

	private
		def validate_configs
			input_policies = self.policies.map(&:to_sym)
			self.configs.each do |key,value|
				if CONFIG_REQUIRED_POLICIES.exclude?(key.to_sym)
					errors.add(:base, I18n.t("password_policy.invalid_config"))
				elsif input_policies.exclude?(key.to_sym)
					#check if the configs given has the corresponding policy checked.
					self.configs[key] = DEFAULT_CONFIGS[key]
				elsif value.present?
					case key
					when "minimum_characters"
						errors.add(:base, I18n.t("password_policy.wrong_password_length")) unless value.in? minimum_character_values
					when "cannot_be_same_as_past_passwords"
						errors.add(:base, I18n.t("password_policy.wrong_no_of_past_password")) unless value.in? password_history_match_values
					when "password_expiry"
						errors.add(:base, I18n.t("password_policy.wrong_expiry_days")) unless value.in? password_expiry_days_values
					when "session_expiry"
						errors.add(:base, I18n.t("password_policy.wrong_expiry_days")) unless value.in? session_expiry_days_values
					end
				end

			end
		end

		def password_policies_changed
			configs_changed? or policies_changed?
		end

		def configs_changed?
			self.previous_changes.key?(:configs) && self.previous_changes[:configs].first != self.previous_changes[:configs].last
		end

		def policies_changed?
			self.previous_changes.key?(:policies) && self.previous_changes[:policies].first != read_attribute(:policies).to_s
		end
end
