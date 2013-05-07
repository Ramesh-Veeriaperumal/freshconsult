# This little guy is needed unless you want to define a helper for every single one of your controllers
MissingSourceFile::REGEXPS << [/^cannot load such file -- (.+)$/i, 1]


 Encoding.default_external = Encoding::UTF_8 if RUBY_VERSION > "1.9"

# TZInfo needs to be patched.  In particular, you'll need to re-implement the datetime_new! method:
require 'tzinfo'

module TZInfo
  
  # Methods to support different versions of Ruby.
  module RubyCoreSupport #:nodoc:
    # Ruby 1.8.6 introduced new! and deprecated new0.
    # Ruby 1.9.0 removed new0.
    # Ruby trunk revision 31668 removed the new! method.
    # Still support new0 for better performance on older versions of Ruby (new0 indicates
    # that the rational has already been reduced to its lowest terms).
    # Fallback to jd with conversion from ajd if new! and new0 are unavailable.
    if DateTime.respond_to? :new!
      def self.datetime_new!(ajd = 0, of = 0, sg = Date::ITALY)
        DateTime.new!(ajd, of, sg)
      end
    elsif DateTime.respond_to? :new0
      def self.datetime_new!(ajd = 0, of = 0, sg = Date::ITALY)
        DateTime.new0(ajd, of, sg)
      end
    else
      HALF_DAYS_IN_DAY = rational_new!(1, 2)

      def self.datetime_new!(ajd = 0, of = 0, sg = Date::ITALY)
        # Convert from an Astronomical Julian Day number to a civil Julian Day number.
        jd = ajd + of + HALF_DAYS_IN_DAY
        
        # Ruby trunk revision 31862 changed the behaviour of DateTime.jd so that it will no
        # longer accept a fractional civil Julian Day number if further arguments are specified.
        # Calculate the hours, minutes and seconds to pass to jd.
        
        jd_i = jd.to_i
        jd_i -= 1 if jd < 0
        hours = (jd - jd_i) * 24
        hours_i = hours.to_i
        minutes = (hours - hours_i) * 60
        minutes_i = minutes.to_i
        seconds = (minutes - minutes_i) * 60
        
        DateTime.jd(jd_i, hours_i, minutes_i, seconds, of, sg)
      end
    end
  end
end

# Finally, we have this innocuous looking patch.  Without it, queries like this: current_account.tickets.recent.count
# would instantiate AR objects all (!!) tickets in the account, not merely return a count of the recent ones.
# See https://rails.lighthouseapp.com/projects/8994/tickets/5410-multiple-database-queries-when-chaining-named-scopes-with-rails-238-and-ruby-192
# (The patch in that lighthouse bug was not, in fact, merged in).
module ActiveRecord
  module Associations
    class AssociationProxy   
      def respond_to_missing?(meth, incl_priv)
        false
      end
    end
  end
end


#IN Ruby 1.9.0 Array.to_s or Hash.to_s allias methods for inspect where as in 1.8.7 to_s is uses join.
class Array
  def to_s
    join
  end
end

class Hash
  def to_s
    to_a.join
  end
end

# #To set yaml parser to syck bcz 1.9.3 the yaml parser is psyck. Untill we fully migrate to 1.9 some times we need to serialize
# #object in one version need to deserialize in another version.(Ex: delayed_jobs and Ticket listview ..etc)
YAML::ENGINE.yamler = "syck" if defined?(YAML::ENGINE)

# In order to have consistent behavior between Ruby 1.8.7 and Ruby 1.9.3, we created a class called CSVBridge, and use that instead of CSV or FasterCSV:
require 'csv'
require 'fastercsv'
 
if CSV.const_defined?(:Reader)
  class CSVBridge < FasterCSV
  end
else
  class CSVBridge < CSV
  end
end








# Drop this file in config/initializers to run your Rails project on Ruby 1.9.
# This is three separate monkey patches -- see comments in code below for the source of each. 
# None of them are original to me, I just put them in one file for easily dropping into my Rails projects.
# Also see original sources for pros and cons of each patch. Most notably, the MySQL patch just assumes
# that everything in your database is stored as UTF-8. This was true for me, and there's a good chance it's
# true for you too, in which case this is a quick, practical solution to get you up and running on Ruby  1.9.
#
# Andre Lewis 1/2010 
 
# encoding: utf-8
 
if RUBY_VERSION > "1.9"
 
  # Force MySQL results to UTF-8.
  #
  # Source: http://gnuu.org/2009/11/06/ruby19-rails-mysql-utf8/
  require 'mysql'
 
  class Mysql::Result
    def encode(value, encoding = "utf-8")
      String === value ? value.force_encoding(encoding) : value
    end
 
    def each_utf8(&block)
      each_orig do |row|
        yield row.map {|col| encode(col) }
      end
    end
    alias each_orig each
    alias each each_utf8
 
    def each_hash_utf8(&block)
      each_hash_orig do |row|
        row.each {|k, v| row[k] = encode(v) }
        yield(row)
      end
    end
    alias each_hash_orig each_hash
    alias each_hash each_hash_utf8
  end
 
 
  #
  # Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
  # (fix_params.rb)
 
  module ActionController
    class Request
      private
 
        # Convert nested Hashs to HashWithIndifferentAccess and replace
        # file upload hashs with UploadedFile objects
        def normalize_parameters(value)
          case value
          when Hash
            if value.has_key?(:tempfile)
              upload = value[:tempfile]
              upload.extend(UploadedFile)
              upload.original_path = value[:filename]
              upload.content_type = value[:type]
              upload
            else
              h = {}
              value.each { |k, v| h[k] = normalize_parameters(v) }
              h.with_indifferent_access
            end
          when Array
            value.map { |e| normalize_parameters(e) }
          else
            value.force_encoding(Encoding::UTF_8) if value.respond_to?(:force_encoding)
            value
          end
        end
    end
  end
 
 
  #
  # Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
  # (fix_renderable.rb)
  #
  module ActionView
    module Renderable #:nodoc:
      private
        def compile!(render_symbol, local_assigns)
          locals_code = local_assigns.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join
 
          source = <<-end_src
            def #{render_symbol}(local_assigns)
              old_output_buffer = output_buffer;#{locals_code};#{compiled_source}
            ensure
              self.output_buffer = old_output_buffer
            end
          end_src
          source.force_encoding(Encoding::UTF_8) if source.respond_to?(:force_encoding)
 
          begin
            ActionView::Base::CompiledTemplates.module_eval(source, filename, 0)
          rescue Errno::ENOENT => e
            raise e # Missing template file, re-raise for Base to rescue
          rescue Exception => e # errors from template code
            if logger = defined?(ActionController) && Base.logger
              logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
              logger.debug "Function body: #{source}"
              logger.debug "Backtrace: #{e.backtrace.join("\n")}"
            end
 
            raise ActionView::TemplateError.new(self, {}, e)
          end
        end
    end
  end
end

require 'date'

if RUBY_VERSION >= '1.9'
  # Modify parsing methods to handle american date format correctly.
  class << Date
    # American date format detected by the library.
    AMERICAN_DATE_RE = eval('%r_(?<!\d)(\d{1,2})/(\d{1,2})/(\d{4}|\d{2})(?!\d)_').freeze
    # Negative lookbehinds, which are not supported in Ruby 1.8
    # so by using eval, we prevent an error when this file is first parsed
    # since the regexp itself will only be parsed at runtime if the RUBY_VERSION condition is met.

    # Alias for stdlib Date._parse
    alias _parse_without_american_date _parse

    # Transform american dates into ISO dates before parsing.
    def _parse(string, comp=true)
      _parse_without_american_date(convert_american_to_iso(string), comp)
    end

    if RUBY_VERSION >= '1.9.3'
      # Alias for stdlib Date.parse
      alias parse_without_american_date parse

      # Transform american dates into ISO dates before parsing.
      def parse(string, comp=true)
        parse_without_american_date(convert_american_to_iso(string), comp)
      end
    end

    private

    # Transform american date fromat into ISO format.
    def convert_american_to_iso(string)
      unless string.is_a?(String)
        if string.respond_to?(:to_str)
          str = string.to_str
          unless str.is_a?(String)
            raise TypeError, "no implicit conversion of #{string.inspect} into String"
          end
          string = str
        else
          raise TypeError, "no implicit conversion of #{string.inspect} into String"
        end
      end
      string.sub(AMERICAN_DATE_RE){|m| "#$3-#$1-#$2"}
    end
  end

  if RUBY_VERSION >= '1.9.3'
    # Modify parsing methods to handle american date format correctly.
    class << DateTime
      # Alias for stdlib Date.parse
      alias parse_without_american_date parse

      # Transform american dates into ISO dates before parsing.
      def parse(string, comp=true)
        parse_without_american_date(convert_american_to_iso(string), comp)
      end
    end
  end
end

