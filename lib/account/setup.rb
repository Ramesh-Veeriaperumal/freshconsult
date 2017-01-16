module Account::Setup

	extend ActiveSupport::Concern

	include Redis::RedisKeys
    include Redis::OthersRedis

	INDEPENDENT_SETUP_KEYS = ["new_account", "account_admin_email", "agents", "support_email", "twitter", "automation", "data_import", "custom_app"]

	FEATURE_BASED_SETUP_KEYS = {
		:freshfone => "freshfone_number"
	}

	SETUP_KEYS = INDEPENDENT_SETUP_KEYS + FEATURE_BASED_SETUP_KEYS.values

	SETUP_KEYS_ORDER = ["new_account", "account_admin_email", "agents", "support_email", "freshfone_number", "twitter", "automation", "data_import", "custom_app"]

	SETUP_EXPIRY = 60.days

	included do |base|
		base.include Binarize
		base.binarize :setup, flags: SETUP_KEYS, not_a_model_column: true
	end

	def setup_key
		@setup_key ||= ACCOUNT_SETUP % {:account_id => self.id}
	end

	def setup
		@setup ||= get_others_redis_key(setup_key).to_i
	end

	def setup=(setup_val)
		@setup = setup_val
	end

	def save_setup
		set_others_redis_with_expiry(setup_key, setup, {:ex => SETUP_EXPIRY})
		@setup = get_others_redis_key(setup_key).to_i
	end

	def current_setup_keys
		@current_setup_keys ||= sort_setup_keys(INDEPENDENT_SETUP_KEYS + current_feature_based_keys)
	end

	def current_feature_based_keys
		FEATURE_BASED_SETUP_KEYS.slice(*(FEATURE_BASED_SETUP_KEYS.keys & (self.feature_from_cache + self.features_list))).values
	end

	def sort_setup_keys(setup_keys)
		setup_keys.sort_by { |setup_key| SETUP_KEYS_ORDER.index setup_key}
	end

	def current_in_setup
		@current_in_setup ||= self.in_setup & current_setup_keys
	end

	SETUP_KEYS.each do |setup_key|
		define_method "mark_#{setup_key}_setup_and_save" do
			self.send("mark_#{setup_key}_setup")
			save_setup
		end
	end

end