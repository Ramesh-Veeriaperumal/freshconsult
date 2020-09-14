module Fdadmin::FeatureMethods

    BITMAP_FEATURES_WITH_VALUES = YAML.load_file(File.join(
      Rails.root, 'config/features', 'features.yml'))[:features][:plan_features][:feature_list]

    BITMAP_FEATURES = BITMAP_FEATURES_WITH_VALUES.keys

    FEATURE_TYPES = ['bitmap', 'launchparty'].freeze

    BLACKLISTED_LP_FEATURES = [:freshid, :freshid_org_v2, :fluffy, :fluffy_min_level].freeze

    BITMAP_FEATURES_TO_IGNORE = [:support_bot, :limit_mobihelp_results, :field_service_management].freeze

    private

    def feature_types(feature_name)
      feature_types = []
      if (Account::LAUNCHPARTY_FEATURES.keys + Account::LP_FEATURES).uniq.include?(feature_name) && !BLACKLISTED_LP_FEATURES.include?(feature_name)
        feature_types << 'launchparty'
        # will be removed after settings implementation
        feature_types << 'bitmap' if BITMAP_FEATURES.include?(feature_name)
      end
      feature_types
    end

    def bitmap_feature_enabled?(feature_name)
      @account.has_feature?(feature_name)
    end     
    
    def db_feature_enabled?(feature_name)
      @account.features?(feature_name)
    end

    def launchparty_feature_enabled?(feature_name)
      @account.launched?(feature_name)
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

    def disable_bitmap_feature(feature_name)
      @account.revoke_feature(feature_name)
    end

    def disable_launchparty_feature(feature_name)
      @account.rollback(feature_name)
    end
end
