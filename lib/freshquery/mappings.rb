module Freshquery
  class Mappings
    attr_accessor :document_type, :fqhelper, :mapping, :es_keys, :date_fields, :query_length

    TYPES = %w(integer positive_integer negative_integer date date_time boolean string).freeze
    CUSTOM_TYPES = %w[custom_string custom_number custom_dropdown].freeze
    VALID_OPTIONS = %w(type choices regex transform mappings).freeze

    @@all_mappings = {}

    def initialize(fqhelper, query_length, validate)
      @fqhelper = fqhelper
      @mapping = {}
      @es_keys = {}
      @default_fields = []
      @date_fields = []
      @date_time_fields = []
      @boolean_fields = []
      @custom_proc = {}
      @custom_choices = {}
      @validate = validate
      @query_length = [Freshquery::Constants::DEFAULT_QUERY_LENGTH, query_length].min
    end

    def sanitize_options(options)
      result = ActiveSupport::HashWithIndifferentAccess.new(options)
      if (result.keys - VALID_OPTIONS).present?
        raise "Invalid option(s) '#{(options.keys - VALID_OPTIONS).join(', ')}', should be any one of '#{VALID_OPTIONS.join(', ')}'"
      end
      result
    end

    def should_validate?
      @validate
    end

    def attribute(*args)
      options = sanitize_options(args.extract_options!)
      if options[:type] && TYPES.exclude?(options[:type].downcase.to_s)
        raise "Invalid type #{options[:type]}, should be any one of '#{TYPES.join(', ')}'"
      end

      args.each do |att|
        hash = {}
        if options[:type]
          hash[:type] = options[:type].to_s
          case hash[:type]
          when 'date'
            @date_fields << options.fetch(:transform, att).to_s
          when 'date_time'
            @date_time_fields << options.fetch(:transform, att).to_s
          when 'boolean'
            @boolean_fields << options.fetch(:transform, att).to_s
          end
        end

        hash[:choices] = options[:choices].to_s if options[:choices]
        hash[:regex] = options[:regex].to_s if options[:regex]
        att = att.to_s
        es_column = options[:transform].to_s if options.key?(:transform)
        es_column = "#{es_column || att}.not_analyzed" if hash[:type] == 'string' || hash.key?(:regex)
        @es_keys[att] = es_column if es_column
        @mapping[att] = hash
        @default_fields << att
      end
    end

    def custom_number(options)
      custom_attributes(options.merge(type: 'integer'))
    end

    def custom_string(options)
      custom_attributes(options.merge(type: 'string'))
    end

    def custom_boolean(options)
      custom_attributes(options.merge(type: 'boolean'))
    end

    def custom_date(options)
      custom_attributes(options.merge(type: 'date'))
    end

    def custom_attributes(options)
      options = sanitize_options(options)
      raise 'mappings proc required for custom data types' unless options[:mappings].present?
      mappings_proc = @fqhelper.safe_send(options[:mappings])
      if mappings_proc.class != Proc
        raise 'mappings should be a proc'
      else
        @custom_proc[options[:type]] = mappings_proc
      end
    end

    def custom_dropdown(options)
      options = sanitize_options(options)
      raise 'mappings proc required for custom data types' unless options[:mappings].present?
      raise 'choices proc required for custom dropdown' unless options[:choices].present?

      mappings_proc = @fqhelper.safe_send(options[:mappings])
      raise 'mappings should be a proc' if mappings_proc.class != Proc

      choices_proc = @fqhelper.safe_send(options[:choices])
      raise 'choices should be a proc' if choices_proc.class != Proc

      @custom_choices = choices_proc
      @custom_proc['dropdown'] = mappings_proc
    end

    def valid?(record)
      validation = Freshquery::Validation.new(self, record)
      validation.valid? ? true : validation
    end

    def to_hash
      result = {}
      if @custom_proc.present?
        @custom_proc.each do |type, proc|
          hash = proc.call
          if hash.class != Hash && hash.class != Array
            raise 'mappings proc should return a Hash or Array object'
          else
            if CUSTOM_TYPES.include?(type)
              result.merge!({ type => { type: type } })
            elsif type == 'dropdown'
              choices = @custom_choices.call
              result.merge!(hash.map { |k, v| [k, { choices: choices.fetch(k, []) }] }.to_h)
            else
              result.merge!(hash.map { |k, v| [k, { type: type }] }.to_h)
            end
          end
        end
      end
      result.except(*@default_fields).merge(@mapping)
    end

    def es_keys
      result = {}
      if @custom_proc.present?
        @custom_proc.each do |type, proc|
          next if CUSTOM_TYPES.include?(type)
          hash = proc.call
          if hash.class != Hash
            raise 'mappings proc should return a Hash object'
          else
            if type == 'string' || type == 'dropdown'
              result.merge!(hash.map { |k, v| [k, "#{v}.not_analyzed"] }.to_h)
            else
              result.merge!(hash)
            end
          end
        end
      end
      result.except(*@default_fields).merge(@es_keys)
    end

    def date_fields
      if @custom_proc['date']
        hash = @custom_proc['date'].call
        return @date_fields + hash.values
      end
      @date_fields
    end

    def date_time_fields
      if @custom_proc['date_time']
        hash = @custom_proc['date_time'].call
        return @date_time_fields + hash.values
      end
      @date_time_fields
    end

    def boolean_fields
      if @custom_proc['boolean']
        hash = @custom_proc['boolean'].call
        return @boolean_fields + hash.values
      end
      @boolean_fields
    end

    def custom_fields
      result = {}
      @custom_proc.each_pair do |key, proc|
        result[key] = proc.call
        result[key] = result[key].map!{|x| "#{x}.not_analyzed"} if ['custom_string', 'custom_dropdown'].include?(key)
      end
      result
    end

    def self.all_mappings
      @@all_mappings
    end

    def self.put(type, mapping)
      @@all_mappings[type] = mapping
    end

    def self.get(type)
      return @@all_mappings[type]
    end
  end
end
