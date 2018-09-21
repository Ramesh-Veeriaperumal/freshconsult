module Account::Setup

  extend ActiveSupport::Concern

  include Redis::RedisKeys
  include Redis::OthersRedis

  ACCOUNT_SETUP_FEATURES_LIST = YAML.load_file(File.join(Rails.root, 'config', 'account_setup_keys.yml'))

  INDEPENDENT_SETUP_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:independent_setup_keys]

  CONDITION_BASED_SETUP_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:condition_based_setup_keys]

  NON_CHECKLIST_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:non_checklist_keys]

  SETUP_KEYS = INDEPENDENT_SETUP_KEYS.merge(CONDITION_BASED_SETUP_KEYS).merge(NON_CHECKLIST_KEYS).sort_by { |key, value| value }.to_h.keys

  SETUP_KEYS_DISPLAY_ORDER = ACCOUNT_SETUP_FEATURES_LIST[:setup_keys_display_order]

  SETUP_EXPIRY = 60.days

  CONTROLLER_SETUP_KEYS = {
  	'discussions' => 'forums',
  	'reports' => 'reports'
   }

  FALCON_SETUP_KEYS = [:reports, :email_notification]

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
    @current_setup_keys ||= sort_setup_keys(INDEPENDENT_SETUP_KEYS.keys + current_condition_based_keys)
  end

  def setup_keys
    SETUP_KEYS_DISPLAY_ORDER
  end

	# For each feature listed in CONDITION_BASED_SETUP_KEYS, add a method that has the corresponding
	# condition checks. The naming convention for the method would be "#{setup_key}_eligible?".
	# For eg., freshfone_number_eligible?

  def current_condition_based_keys
    CONDITION_BASED_SETUP_KEYS.keys.select { |setup_key| safe_send("#{setup_key}_eligible?") }
  end

  def freshfone_number_eligible?
    has_feature?(:freshcaller) && phone_channel_enabled?
  end

  def twitter_eligible?
    social_channel_enabled?
  end

  def forums_eligible?
    self.falcon_ui_enabled?(User.current) && self.features_included?(:forums)
  end

	# TRIAL WIDGET CLEANUP - can be removed after trial widget deprecation
	def custom_app_eligible?
		!self.launched?(:new_onboarding)
	end

	# TRIAL WIDGET CLEANUP - can be removed after trial widget deprecation
	def reports_eligible?
		!self.launched?(:new_onboarding)
	end


	FALCON_SETUP_KEYS.each do |setup_key|
		define_method "#{setup_key}_eligible?" do
			self.falcon_ui_enabled?(User.current)
		end
	end

  def sort_setup_keys(setup_keys)
    setup_keys.sort_by { |setup_key| SETUP_KEYS_DISPLAY_ORDER.index setup_key}
  end

  def current_in_setup
    @current_in_setup ||= self.in_setup & current_setup_keys
  end

	SETUP_KEYS.each do |setup_key|
		define_method "mark_#{setup_key}_setup_and_save" do
			self.safe_send("mark_#{setup_key}_setup")
			save_setup
		end
	end

  SETUP_KEYS.each do |setup_key|
    define_method "unmark_#{setup_key}_setup_and_save" do
      self.safe_send("unmark_#{setup_key}_setup")
      save_setup
    end
  end

end
