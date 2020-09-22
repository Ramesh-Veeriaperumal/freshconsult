module Account::Setup

  extend ActiveSupport::Concern

  include Redis::RedisKeys
  include Redis::OthersRedis

  ACCOUNT_SETUP_FEATURES_LIST = YAML.load_file(File.join(Rails.root, 'config', 'account_setup_keys.yml'))

  INDEPENDENT_SETUP_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:independent_setup_keys]

  CONDITION_BASED_SETUP_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:condition_based_setup_keys]

  NON_CHECKLIST_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:non_checklist_keys]

  ONBOARDING_V2_KEYS = ACCOUNT_SETUP_FEATURES_LIST[:onboarding_v2_keys]

  SETUP_KEYS = INDEPENDENT_SETUP_KEYS.merge(CONDITION_BASED_SETUP_KEYS).merge(NON_CHECKLIST_KEYS).merge(ONBOARDING_V2_KEYS).sort_by { |key, value| value }.to_h.keys

  SETUP_KEYS_DISPLAY_ORDER = ACCOUNT_SETUP_FEATURES_LIST[:setup_keys_display_order]

  ONBOARDING_V2_GOALS = ACCOUNT_SETUP_FEATURES_LIST[:onboarding_v2_goals]

  FRESHMARKETER_EVENTS = ACCOUNT_SETUP_FEATURES_LIST[:freshmarketer_events].keys

  SETUP_EXPIRY = 60.days

  CONTROLLER_SETUP_KEYS = {
  	'discussions' => 'forums',
  	'reports' => 'reports'
   }

  FALCON_SETUP_KEYS = [:reports, :email_notification]

  included do |base|
    base.include Binarize
    base.binarize :setup, flags: SETUP_KEYS + ONBOARDING_V2_GOALS + FRESHMARKETER_EVENTS, not_a_model_column: true
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
    self.features_included?(:forums)
  end

  # TRIAL WIDGET CLEANUP - can be removed after trial widget deprecation
  def custom_app_eligible?
    false
  end

  # TRIAL WIDGET CLEANUP - can be removed after trial widget deprecation
  def reports_eligible?
    false
  end


	FALCON_SETUP_KEYS.each do |setup_key|
		define_method "#{setup_key}_eligible?" do
			true
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

  ONBOARDING_V2_GOALS.each do |setup_goal|
    define_method "mark_#{setup_goal}_setup_and_save" do
      self.safe_send("mark_#{setup_goal}_setup")
      AddEventToFreshmarketer.perform_async(event: ThirdCRM::FRESHMARKETER_EVENTS[:goal_completed], goal_name: TrialWidgetConstants::GOALS_AND_STEPS[setup_goal.to_sym][:goal_alias_name])
      save_setup
    end
  end

  ONBOARDING_V2_GOALS.each do |setup_goal|
    define_method "unmark_#{setup_goal}_setup_and_save" do
      self.safe_send("unmark_#{setup_goal}_setup")
      save_setup
    end
  end

  FRESHMARKETER_EVENTS.each do |event_name|
    define_method "mark_#{event_name}_setup_and_save" do
      self.safe_send("mark_#{event_name}_setup")
      AddEventToFreshmarketer.perform_async(event: ThirdCRM::FRESHMARKETER_EVENTS[:fdesk_event], event_name: event_name.titleize)
      save_setup
    end
  end

  FRESHMARKETER_EVENTS.each do |setup_key|
    define_method "unmark_#{setup_key}_setup_and_save" do
      self.safe_send("unmark_#{setup_key}_setup")
      save_setup
    end
  end

end
