module Freshquery::Model
  extend ActiveSupport::Concern

  module InstanceMethods
    def all_mappings
      Freshquery::Mappings.all_mappings
    end

    def get_mapping(type)
      Freshquery::Mappings.get(type)
    end

    def construct_es_query(type, query, v_mapping = false)
      parser = Freshquery::Parser::SearchParser.new
      mapping = get_mapping(type)
      tree = construct_expression_tree(query.strip, parser, mapping.query_length)
      record = parser.record
      valid = mapping.should_validate? ? mapping.valid?(record) : true
      if valid == true
        visitor_mapping = v_mapping || visitor(mapping)
        Freshquery::Response.new(true, tree.accept(visitor_mapping))
      else
        Freshquery::Response.new(false, nil, valid)
      end
    rescue Freshquery::Errors::QueryLengthException => e
      Freshquery::Utils.error_response(nil, :query, Freshquery::Constants::QUERY_LENGTH_INVALID % {current_count: e.to_s, max_count: mapping.query_length})
    rescue Freshquery::Errors::QueryFormatException => e
      Freshquery::Utils.error_response(nil, :query, Freshquery::Constants::QUERY_FORMAT_INVALID)
    end

    def construct_expression_tree(query, parser, length)
      if query !~ Freshquery::Constants::STRING_WITHIN_QUOTES
        raise Freshquery::Errors::QueryFormatException
      else
        begin
          query = query[1..- 2].strip
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
    def fq_schema(document_type, fqhelper, query_length, validate = true, &block)
      raise 'Attibutes block required' unless block_given?
      mapping = Freshquery::Mappings.new(fqhelper, query_length, validate)
      Freshquery::Mappings.put(document_type, mapping)
      mapping.instance_eval(&block)
    end
  end
end
