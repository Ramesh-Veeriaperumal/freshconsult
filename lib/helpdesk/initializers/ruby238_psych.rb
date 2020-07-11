YAML = Psych

module ActiveRecord
  # :stopdoc:
  module Coders
    # PRE-RAILS: Overridden default coders as issue with backward compatibility of memcache deserialize with new coder.
    class YAMLColumn

      def dump(obj)
        begin
          obj_class = obj.class
          obj = convert(obj)
        rescue StandardError => e
          raise "Serialized attribute parse exception: #{e.message} :: #{object_class} :: #{obj_class} :: #{obj.class} :: #{e.backtrace}"
        end
        YAML.dump(obj)
      end

      def load(yaml, syck_load = false)
        # PRE-RAILS: Used Syck as fallback for Psych.load failures.
        return object_class.new if object_class != Object && yaml.nil?
        return yaml unless yaml.is_a?(String) && yaml =~ /^---/
        begin
          obj = syck_load ? Syck.load(yaml) : YAML.load(yaml)
          
          unless obj.is_a?(object_class) || obj.nil?
            raise SerializationTypeMismatch,
              "Syck Load: Attribute was supposed to be a #{object_class}, but was a #{obj.class}"
          end
          obj ||= object_class.new if object_class != Object

          obj
        rescue Psych::SyntaxError
          syck_load ? yaml : load(yaml, true)
        rescue ArgumentError
          yaml
        end
      end

      private

        def convert(obj)
          if obj.is_a?(Array)
            obj.map { |value| convert(value) }
          elsif obj.is_a?(Hash)
            new_hash = [ActionController::Parameters, ActiveSupport::HashWithIndifferentAccess].include?(obj.class) ? ActiveSupport::HashWithIndifferentAccess.new : {}
            obj.each_with_object(new_hash) do |(key, value), hash|
              if value.is_a?(Array)
                hash[key] = value.map { |v| convert(v) }
              elsif value.class == ActionController::Parameters
                hash[key] = convert(value.to_hash.with_indifferent_access)
              elsif [Hash, ActiveSupport::HashWithIndifferentAccess].include?(value.class)
                hash[key] = convert(value)
              elsif value.class == ActiveSupport::SafeBuffer
                hash[key] = String.new(value)
              else
                hash[key] = value
              end
            end
          else
            obj
          end
        end
    end
  end
  # :startdoc

  class Base
    def self.serialize(attr_name, class_name = Object)
      # When ::JSON is used, force it to go through the Active Support JSON encoder
      # to ensure special objects (e.g. Active Record models) are dumped correctly
      # using the #as_json hook.
      coder = if [:load, :dump].all? { |x| class_name.respond_to?(x) }
        class_name
      elsif class_name.is_a?(Array)
        Coders::YAMLColumn.new(Object)
      else
        Coders::YAMLColumn.new(class_name)
      end

      self.serialized_attributes = serialized_attributes.merge(attr_name.to_s => coder)
    end
  end
end