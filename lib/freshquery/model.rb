module Freshquery::Model
  extend ActiveSupport::Concern

  class Mappings
    attr_accessor :document_type, :fqhelper, :mapping, :es_keys, :date_fields, :query_length

    TYPES = %w(integer positive_integer negative_integer date boolean string).freeze
    CUSTOM_TYPES = %w(integer date boolean string).freeze
    VALID_OPTIONS = %i(type choices regex transform mappings).freeze

    @@all_mappings = {}
    @@query_length

    def initialize(fqhelper, query_length = 512)
      @fqhelper = fqhelper
      @@all_mappings[document_type] = {}
      @mapping = {}
      @es_keys = {}
      @default_fields = []
      @date_fields = []
      @boolean_fields = []
      @custom_proc = {}
      @custom_choices = {}
      @query_length = query_length > 512 ? 512 : query_length
    end

    def sanitize_options(options)
      result = {}
      options.map{ |k, v| result[k.downcase.to_sym] = v }
      if (result.keys - VALID_OPTIONS).present?
        raise "Invalid option(s) '#{(options.keys - VALID_OPTIONS).join(', ')}', should be any one of '#{VALID_OPTIONS.join(', ')}'"
      end
      result
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
          @date_fields << options.fetch(:transform, att).to_s if hash[:type] == 'date'
          @boolean_fields << options.fetch(:transform, att).to_s if hash[:type] == 'boolean'
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
    alias custom_integer custom_number

    def custom_string(options)
      custom_attributes(options.merge(type: 'string'))
    end

    def custom_boolean(options)
      custom_attributes(options.merge(type: 'boolean'))
    end
    alias custom_checkbox custom_boolean

    def custom_date(options)
      custom_attributes(options.merge(type: 'date'))
    end

    def custom_attributes(options)
      options = sanitize_options(options)
      raise 'mappings proc required for custom data types' unless options[:mappings].present?
      if options[:mappings]
        proc = @fqhelper.send(options[:mappings])
        if proc.class != Proc
          raise 'mappings should be a proc'
        else
          @custom_proc[options[:type]] = proc
        end
      end
    end

    def custom_dropdown(options)
      options = sanitize_options(options)
      raise 'mappings proc required for custom data types' unless options[:mappings].present?
      raise 'choices proc required for custom dropdown' unless options[:choices].present?

      mappings_proc = @fqhelper.send(options[:mappings])
      raise 'mappings should be a proc' if mappings_proc.class != Proc

      choices_proc = @fqhelper.send(options[:choices])
      raise 'choices should be a proc' if choices_proc.class != Proc

      @custom_choices = choices_proc
      @custom_proc['dropdown'] = mappings_proc
    end

    def to_hash
      result = {}
      if @custom_proc.present?
        @custom_proc.each do |type, proc|
          hash = proc.call
          if hash.class != Hash
            raise 'mappings proc should return a Hash object'
          else
            if type == 'dropdown'
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

    def boolean_fields
      if @custom_proc['boolean']
        hash = @custom_proc['boolean'].call
        return @boolean_fields + hash.values
      end
      @boolean_fields
    end

    def self.put(type, mapping)
      @@all_mappings[type] = mapping
    end

    def self.all_mappings
      @@all_mappings
    end

    def self.get(type, fqhelper = nil, query_length = 512)
      return @@all_mappings[type] if @@all_mappings.key?(type)
      raise 'Validation Helper class required' unless fqhelper
      @@all_mappings[type] = Mappings.new(fqhelper, query_length)
    end
  end

  module InstanceMethods
    def all_mappings
      Mappings.all_mappings
    end

    def get_mapping(type)
      Mappings.get(type)
    end

    def valid?(mapping, record)
      validation = Freshquery::Validation.new(mapping, record)
      validation.valid? ? true : validation
    end

    def construct_es_query(type, query)
      parser = Freshquery::Parser::SearchParser.new
      mapping = get_mapping(type)
      tree = construct_expression_tree(query.strip, parser, mapping.query_length)
      record = parser.record      
      valid = valid?(mapping, record)
      if valid == true
        Freshquery::Response.new(true, tree.accept(visitor(mapping)))
      else
        Freshquery::Response.new(false, nil, valid)
      end
    rescue Freshquery::Errors::QueryLengthException => e
      errors = ActiveModel::Errors.new(Object.new)
      errors.messages[:query] = [Freshquery::Constants::QUERY_LENGTH_INVALID % {current_count: e.to_s, max_count: mapping.query_length}]
      response = Freshquery::Response.new(false, nil, nil)
      response.errors = errors
      response
    rescue Freshquery::Errors::QueryFormatException => e
      errors = ActiveModel::Errors.new(Object.new)
      errors.messages[:query] = [Freshquery::Constants::QUERY_FORMAT_INVALID]
      response = Freshquery::Response.new(false, nil, nil)
      response.errors = errors
      response
    end

    def construct_expression_tree(query, parser, length)
      if query !~ Freshquery::Constants::STRING_WITHIN_QUOTES
        raise Freshquery::Errors::QueryFormatException
      else
        begin
          query = query[1, query.length - 2].strip
          raise Freshquery::Errors::QueryLengthException.new(query.size) if query.size > length
          parser.parse(query)
          tree = parser.expression_tree
        rescue Racc::ParseError
          raise Freshquery::Errors::QueryFormatException
        end
      end
    end

    def visitor(mapping)
      Freshquery::Parser::TermVisitor.new(mapping)
    end
  end # Instance methods

  module ClassMethods
    def fq_mappings(document_type, fqhelper, query_length = 512, &block)
      raise 'Attibutes block required' unless block_given?
      mapping = Mappings.get(document_type, fqhelper, query_length )
      mapping.instance_eval(&block)
    end
    alias mappings fq_mappings
  end
end
