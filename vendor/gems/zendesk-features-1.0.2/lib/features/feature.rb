require 'features/active_record_extension'

module Features
  class RequirementsError < StandardError
  end

  # If you want to add a feature, simply define a suitable symbol to Feature::LIST. If for example you
  # want to define the "wiffle feature", add :wiffle and you can subsequenctly do:
  #
  #   account.features.wiffle?
  #   account.features.wiffle.destroy
  #   account.features.wiffle.create
  #
  class Feature < ActiveRecord::Base
    
    abstract_class = true

    self.primary_key = :id
    self.table_name = :features
  
    LIST = []
  
    after_create :reset_owner_association, :send_event_to_mixpanel
    after_destroy :reset_owner_association, :send_event_to_mixpanel
    before_destroy :destroy_dependant_features, :clear_features_from_cache
    before_create :clear_features_from_cache

    after_create :add_bitmap_or_lp_feature
    after_destroy :revoke_bitmap_or_lp_feature
    belongs_to :account, inverse_of: :features
  
    def available?
      feature_owner_instance.features.available?(to_sym)
    end
  
    def create
      if new_record?
        raise RequirementsError.new unless available?
        super
      end
      self
    end
    
    def matches?(sym)
      to_sym == sym.to_sym
    end  
  
    def to_sym
      @sym ||= Feature.class_to_sym(self.class)
    end
    
    def self.to_sym
      @sym ||= Feature.class_to_sym(self)
    end
    
    def self.class_to_sym(klass)
      klass.name.tableize.tableize[0..-10].to_sym
    end
    
    def self.sym_to_name(sym)
      "#{sym.to_s.camelize}Feature"
    end
    
    def self.sym_to_class(sym)
      sym_to_name(sym).constantize
    end
    
    def self.protected?
      @protect || false
    end
    def protected?
      self.class.protected?
    end
    
    def self.required_features
      @required_features ||= []
    end
    def required_features
      self.class.required_features
    end
    
    def self.dependant_features
      @dependant_features ||= []
    end
    def dependant_features
      self.class.dependant_features
    end
    
    private

      def add_bitmap_or_lp_feature
        feature_name = Account::FEATURE_NAME_CHANGES[to_sym] || to_sym
        if Account::DB_TO_LP_MIGRATION_P2_FEATURES_LIST.include? to_sym
          account.launch(feature_name)
        elsif Account::DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST.include? to_sym
          if Account.current.present? # to handle signups
            account.add_feature(feature_name)
          else
            account.set_feature(feature_name)
          end
        else
          Rails.logger.info "FEATURE #{feature_name} not migrated"
        end
      end

      def revoke_bitmap_or_lp_feature
        feature_name = Account::FEATURE_NAME_CHANGES[to_sym] || to_sym
        if Account::DB_TO_LP_MIGRATION_P2_FEATURES_LIST.include? to_sym
          account.rollback(feature_name)
        elsif Account::DB_TO_BITMAP_MIGRATION_P2_FEATURES_LIST.include? to_sym
          account.revoke_feature(feature_name)
        else
          Rails.logger.info "FEATURE #{feature_name} not migrated"
        end
      end
    
    def feature_owner_instance
      safe_send(self.class.feature_owner)
    end
    def update_owner_timestamp
      feature_owner_instance.update_attribute(:updated_at, Time.now) if feature_owner_instance && !feature_owner_instance.new_record?
    end
    
    def reset_owner_association
      feature_owner_instance.features.reload
    end
    
    def destroy_dependant_features
      dependant_features.each do |dependant|
        feature_owner_instance.features.safe_send(dependant.to_sym).destroy
      end
    end
    
    def self.protect!
      @protect = true
    end
    
    def self.required_features=(required_features)
      @required_features = required_features
    end
    def self.dependant_features=(dependant_features)
      @dependant_features = dependant_features
    end
    
    def self.feature_owner=(owner_class)
      @feature_owner_sym = owner_class.name.underscore.to_sym
      belongs_to @feature_owner_sym
      validates_presence_of @feature_owner_sym
      validates_uniqueness_of :type, :scope => feature_owner_key
      # Commented out to avoid account model update for every feature addition/deletion.
      # if owner_class.table_exists? && owner_class.column_names.include?('updated_at')
      #   before_create :update_owner_timestamp
      #   before_destroy :update_owner_timestamp
      # end
    end
    
    def self.feature_owner
      @feature_owner_sym
    end
    
    def self.feature_owner_key
      "#{feature_owner}_id".to_sym
    end

    def clear_features_from_cache
      Account.current.try(:reset_feature_from_cache_variable)
      # update the version timestamp to reflect any feature addition to falcon apis.
      # revisit later to write it better.
      Account.current.try(:versionize_timestamp)
      
      key = ::MemcacheKeys::FEATURES_LIST % { :account_id => self.account_id }
      ::MemcacheKeys.delete_from_cache key
    end

    def send_event_to_mixpanel
      ::MixpanelWrapper.send_to_mixpanel(self.class.name, { :enabled => self.account.features?(to_sym) })
    end
  end

end
