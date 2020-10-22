module Fdadmin::FeatureMethods

    BITMAP_FEATURES_WITH_VALUES = YAML.load_file(Rails.root.join('config/features', 'features.yml'))[:features][:plan_features][:feature_list]

    SELECTABLE_FEATURES_LIST = YAML.load_file(Rails.root.join('config/features', 'features.yml'))[:selectable_features].keys

    SETTINGS_FEATURES = YAML.load_file(Rails.root.join('config/features', 'settings.yml'))['settings']

    INTERNAL_SETTINGS = SETTINGS_FEATURES.select { |x| SETTINGS_FEATURES[x]['internal'] }.keys

    BITMAP_FEATURES = BITMAP_FEATURES_WITH_VALUES.keys

    FEATURE_TYPES = ['bitmap', 'launchparty', 'setting'].freeze

    BLACKLISTED_LP_FEATURES = [:freshid, :freshid_org_v2, :fluffy, :fluffy_min_level].freeze

    BITMAP_FEATURES_TO_IGNORE = [:support_bot].freeze

    LAUNCH_PARTY_ACTIONS = ['add_launch_party', 'remove_launch_party'].freeze

    SETTINGS_ACTIONS = ['add_setting', 'remove_setting'].freeze

    SELECTABLE_FEATURES_ACTION = ['add_selectable_feature', 'remove_selectable_feature'].freeze

    private

    def feature_types(feature_name)
      feature_types = []
      action = params['action']
      if LAUNCH_PARTY_ACTIONS.include?(action) && enableable_lp?(feature_name)
        feature_types << 'launchparty'
      elsif SETTINGS_ACTIONS.include?(action) && valid_setting?(feature_name)
        feature_types << 'setting'
      elsif SELECTABLE_FEATURES_ACTION.include?(action) && SELECTABLE_FEATURES_LIST.include?(feature_name)
        feature_types << 'bitmap'
      end
      feature_types
    end

    def bitmap_feature_enabled?(feature_name)
      @account.has_feature?(feature_name)
    end

    def launchparty_feature_enabled?(feature_name)
      @account.launched?(feature_name)
    end

    def setting_feature_enabled?(feature_name)
      (@account.internal_setting_for_account?(feature_name) && @account.safe_send("#{feature_name}_enabled?")) ||
        (launchparty_feature_enabled?(feature_name) && bitmap_feature_enabled?(feature_name))
    end

    FEATURE_TYPES.each do |feature_type|
      define_method("#{feature_type}_feature_disabled?") do |feature_name|
        !safe_send("#{feature_type}_feature_enabled?", feature_name)
      end
    end

    def enableable?(feature_name)
      feature_types = feature_types(feature_name)
      raise "Invalid feature name" if feature_types.blank?
      feature_types(feature_name).any? do |feature_type|
        safe_send("#{feature_type}_feature_disabled?", feature_name) 
      end
    end

    def disableable?(feature_name)
      feature_types = feature_types(feature_name)
      raise "Invalid feature name" if feature_types.blank?
      feature_types(feature_name).any? do |feature_type|
        safe_send("#{feature_type}_feature_enabled?", feature_name) 
      end
    end

    ["enable", "disable"].each do |toggle_setting|
      define_method("#{toggle_setting}_feature") do |feature_name|
        feature_types = feature_types(feature_name)
        raise "Invalid feature name" if feature_types.blank?
        ActiveRecord::Base.transaction do
          feature_types.each do |feature_type|
            safe_send("#{toggle_setting}_#{feature_type}_feature", feature_name)
          end
        end
        true
      end
    end

    def enable_bitmap_feature(feature_name)
      #hack. but couldnt find a better way at the last moment. will remove the check later.
      if feature_name.to_sym == :falcon
        @account.enable_falcon_ui
      elsif feature_name.to_sym.in?(BITMAP_FEATURES_TO_IGNORE)
        raise 'Not applicable'
      else
        @account.add_feature(feature_name)
      end
    end

    def enable_launchparty_feature(feature_name)
      @account.launch(feature_name)
    end

    def enable_setting_feature(feature_name)
      @account.enable_setting(feature_name)
    end

    def disable_bitmap_feature(feature_name)
      @account.revoke_feature(feature_name)
    end

    def disable_launchparty_feature(feature_name)
      @account.rollback(feature_name)
    end

    def disable_setting_feature(feature_name)
      @account.disable_setting(feature_name)
    end

    def enableable_lp?(feature_name)
      (Account::LAUNCHPARTY_FEATURES.keys + Account::LP_FEATURES).uniq.include?(feature_name) && !BLACKLISTED_LP_FEATURES.include?(feature_name)
    end

    def valid_setting?(feature_name)
      INTERNAL_SETTINGS.include?(feature_name) || Account::LP_TO_BITMAP_MIGRATION_FEATURES.include?(feature_name)
    end
end
