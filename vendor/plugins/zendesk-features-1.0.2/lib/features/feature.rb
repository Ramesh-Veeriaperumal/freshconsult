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
  
    LIST = []
  
    after_create :reset_owner_association
    after_destroy :reset_owner_association
    before_destroy :destroy_dependant_features
  
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
    
    def feature_owner_instance
      send(self.class.feature_owner)
    end
    def update_owner_timestamp
      feature_owner_instance.update_attribute(:updated_at, Time.now) if feature_owner_instance && !feature_owner_instance.new_record?
    end
    
    def reset_owner_association
      feature_owner_instance.features.reload
    end
    
    def destroy_dependant_features
      dependant_features.each do |dependant|
        feature_owner_instance.features.send(dependant.to_sym).destroy
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
      if owner_class.table_exists? && owner_class.column_names.include?('updated_at')
        before_create :update_owner_timestamp
        before_destroy :update_owner_timestamp
      end
    end
    
    def self.feature_owner
      @feature_owner_sym
    end
    
    def self.feature_owner_key
      "#{feature_owner}_id".to_sym
    end
  end

end
