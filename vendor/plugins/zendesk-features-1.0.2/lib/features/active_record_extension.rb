module Features
  module ActiveRecordExtension
    module ClassMethods
      def has_features(&block)
        builder = FeatureTreeBuilder.new(self)
        builder.instance_eval(&block)
        builder.build

        has_many :features, :class_name => 'Features::Feature', :dependent => :destroy do
          def available?(feature_name)
            @owner.features?(*Feature.sym_to_class(feature_name).required_features.map(&:to_sym))
          end
          
          def build(*feature_names)
            feature_names.each do |feature_name|
              self << Feature.sym_to_class(feature_name).new
            end
          end
          
          # Define the feature query methods, given that the feature +wiffle+ is defined,
          # then the methods +account.features.wiffle?+ and +account.features.wiffle!+ will
          # be available
          Feature::LIST.each do |f|

            # The query method, does this account have a given feature? account.features.wiffle?
            define_method "#{f}?" do
              any? { |feature| feature.matches?(f) }
            end

            # The finder method which returns the feature if present, otherwise a new instance, allows
            # non-destructive create and delete operations:
            #
            #   account.features.wiffle.destroy
            #   account.features.wiffle.create
            #
            # In the latter case, a the +wiffle+ feature will only be enabled if it's not already. Be careful
            # not to confuse this method with the "feature enabled" method above, ie. avoid
            #
            #   format_c if account.feature.wiffle
            #
            define_method "#{f}" do
              instance = detect { |feature| feature.matches?(f) }
              instance ||= Feature.sym_to_class(f).new(@owner.class.name.underscore.to_sym => @owner)
            end
          end
        end
        
        include Features::ActiveRecordExtension::InstanceMethods
        alias_method_chain :update_attributes, :features
        alias_method_chain :update_attributes!, :features
        
      end
    end

    module InstanceMethods
      # Allows you to check for multiple features like account.features?(:suggestions, :suggestions_on_web)
      def features?(*feature_names)
        feature_names.all? { |feature_name| features.send("#{feature_name}?") }
      end

      def update_attributes_with_features(attributes)
        update_feature_attributes(attributes)
        update_attributes_without_features(attributes)
      end

      def update_attributes_with_features!(attributes)
        update_feature_attributes(attributes)
        update_attributes_without_features!(attributes)
      end

      private

      def update_feature_attributes(attributes)
        if attributes && feature_attributes = attributes.delete(:features)
          feature_attributes.each do |feature_name, value|
            feature = features.send(feature_name)
            if feature.protected?
              logger.warn("someone tried to mass update the protected #{feature_name} feature")
            else
              if value == '1' || value == true
                feature.create
              else
                feature.destroy
              end
            end
          end
          features.reset
        end
      end
    end
    
    class FeatureTreeBuilder
      def initialize(owner_class)
        @owner_class = owner_class
        @definitions = Hash.new
      end
      
      def feature(name, options = {})
        raise("Feature name '#{name}' is too long. Max 28 characters please...") if name.to_s.size > 28
        feature_options = options.reverse_merge({:requires => [], :dependants => [], :protected => false})
        feature_options[:requires] = [*feature_options[:requires]].uniq
        @definitions[name.to_sym] = feature_options
      end
      
      def resolve_dependencies
        @definitions.each do |name, options|
          options[:requires].each do |required_feature_name|
            @definitions[required_feature_name][:dependants] << name
          end
        end
      end
      
      def build
        resolve_dependencies
        #defines the feature classes
        @definitions.each do |name, options|
          new_feature = Object.const_set(Feature.sym_to_name(name), Class.new(Feature))
          new_feature.feature_owner = @owner_class
        end
        
        #sets the feature classes options
        @definitions.each do |name, options|
          new_feature = Feature.sym_to_class(name)
          new_feature.protect! if options[:protected]
          new_feature.required_features = options[:requires].map {|f| Feature.sym_to_class(f)}
          new_feature.dependant_features = options[:dependants].map {|f| Feature.sym_to_class(f)}

          Feature::LIST << name
        end
      end
    end

    def self.included(receiver)
      receiver.extend ClassMethods
    end
  end
end

ActiveRecord::Base.class_eval do
  include Features::ActiveRecordExtension
end
