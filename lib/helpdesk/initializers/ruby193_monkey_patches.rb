# This little guy is needed unless you want to define a helper for every single one of your controllers
MissingSourceFile::REGEXPS << [/^cannot load such file -- (.+)$/i, 1]


 

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
# TODO-RAILS3 need to cross check
# module ActiveRecord
#   module Associations
#     class AssociationProxy
#       def respond_to_missing?(meth, incl_priv)
#         false
#       end
#     end
#   end
# end

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
class CSVBridge < CSV
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
 


Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8


# Serialized columns in AR don't support UTF-8 well, so set the encoding on those as well.
# TODO-RAILS3 need to cross check
# class ActiveRecord::Base
  # TODO-RAILS3 need to cross check this one is need or not
  # def unserialize_attribute_with_utf8(attr_name)
  #   traverse = lambda do |object, block|
  #     if object.kind_of?(Hash)
  #       object.each_value { |o| traverse.call(o, block) }
  #     elsif object.kind_of?(Array)
  #       object.each { |o| traverse.call(o, block) }
  #     else
  #       block.call(object)
  #     end
  #     object
  #   end
  #   force_encoding = lambda do |o|
  #     o.force_encoding(Encoding::UTF_8) if o.respond_to?(:force_encoding)
  #   end
  #   value = unserialize_attribute_without_utf8(attr_name)
  #   traverse.call(value, force_encoding)
  # end
  # alias_method_chain :unserialize_attribute, :utf8

  # https://rails.lighthouseapp.com/projects/8994/tickets/2283 Backport patch to 2-3-stable. to fix Module is not missing Model error
  # TODO-RAILS3 freshservice need to check this
  # (class << self; self; end).instance_eval do 
  #   define_method "compute_type_with_class_load_fix" do |type_name|
  #     if type_name.match(/^::/)
  #       # If the type is prefixed with a scope operator then we assume that
  #       # the type_name is an absolute reference.
  #       type_name.constantize
  #     else
  #       # Build a list of candidates to search for
  #       candidates = []
  #       name.scan(/::|$/) { candidates.unshift "#{$`}::#{type_name}" }
  #       candidates << type_name

  #       candidates.each do |candidate|
  #         begin
  #           constant = candidate.constantize
  #           return constant if candidate == constant.to_s
  #         rescue NameError
  #         rescue ArgumentError
  #         end
  #       end

  #       raise NameError, "uninitialized constant #{candidates.first}"
  #     end
  #   end
  #   alias_method_chain :compute_type, :class_load_fix
  # end if Rails.env.development?
  
# end

#https://developer.uservoice.com/blog/2012/03/04/how-to-upgrade-a-rails-2-3-app-to-ruby-1-9-3/
# TODO-RAILS3 need to cross check
# module ActionController
#   module Flash
#     class FlashHash
#       def [](k)
#         v = super
#         v.is_a?(String) ? v.force_encoding("UTF-8") : v
#       end
#     end
#   end
# end

# class ActionController::InvalidByteSequenceErrorFromParams < Encoding::InvalidByteSequenceError; end

#
# Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
# (fix_params.rb)


# TODO-RAILS3 - need to force-encode attachment file's name to UTF-8
module ActionDispatch
  module Http
    module Parameters
      private

      def normalize_parameters(value)
        case value
        when Hash
          h = {}
          value.each { |k, v| h[normalize_parameters(k.dup)] = normalize_parameters(v) }
          h.with_indifferent_access
        when Array
          value.map { |e| normalize_parameters(e) }
        else
          value.force_encoding(Encoding::UTF_8) if value.respond_to?(:force_encoding)
          value
        end
      end

    end
  end
end


#
# Source: https://rails.lighthouseapp.com/projects/8994/tickets/2188-i18n-fails-with-multibyte-strings-in-ruby-19-similar-to-2038
# (fix_renderable.rb)
#
# TODO-RAILS3 need to cross check
# module ActionView
#   module Renderable #:nodoc:

#     def render(view, local_assigns = {})
#       compile(local_assigns)

#       view.force_encoding(Encoding::UTF_8) if view.respond_to?(:force_encoding)

#       view.with_template self do
#         view.send(:_evaluate_assigns_and_ivars)
#         view.send(:_set_controller_content_type, mime_type) if respond_to?(:mime_type)

#         view.send(method_name(local_assigns), local_assigns) do |*names|
#           ivar = :@_proc_for_layout
#           if !view.instance_variable_defined?(:"@content_for_#{names.first}") && view.instance_variable_defined?(ivar) && (proc = view.instance_variable_get(ivar))
#             view.capture(*names, &proc)
#           elsif view.instance_variable_defined?(ivar = :"@content_for_#{names.first || :layout}")
#             view.instance_variable_get(ivar)
#           end
#         end
#       end
#     end

#     private
#       def compile!(render_symbol, local_assigns)
#         locals_code = local_assigns.keys.map { |key| "#{key} = local_assigns[:#{key}];" }.join

#         source = <<-end_src
#           # encoding: utf-8
#           def #{render_symbol}(local_assigns)
#             old_output_buffer = output_buffer;#{locals_code};#{compiled_source}
#           ensure
#             self.output_buffer = old_output_buffer
#           end
#         end_src
#         source.force_encoding(Encoding::UTF_8) if RUBY_VERSION >= '1.9.3'

#         begin
#           ActionView::Base::CompiledTemplates.module_eval(source, filename, 0)
#         rescue Errno::ENOENT => e
#           raise e # Missing template file, re-raise for Base to rescue
#         rescue Exception => e # errors from template code
#           if logger = defined?(ActionController) && Base.logger
#             logger.debug "ERROR: compiling #{render_symbol} RAISED #{e}"
#             logger.debug "Function body: #{source}"
#             logger.debug "Backtrace: #{e.backtrace.join("\n")}"
#           end

#           raise ActionView::TemplateError.new(self, {}, e)
#         end
#       end
#   end
# end

require 'date'

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

# Modify parsing methods to handle american date format correctly.
class << DateTime
  # Alias for stdlib Date.parse
  alias parse_without_american_date parse

  # Transform american dates into ISO dates before parsing.
  def parse(string, comp=true)
    parse_without_american_date(convert_american_to_iso(string), comp)
  end
end

class Mysql2::Result
  def fetch_hash
    each(:as => :hash).first
  end
end

#memcache marshel load monkey patch...
module Marshal
  class << self
    def load_with_utf8_enforcement(object, other_proc=nil)
      @utf8_proc ||= Proc.new do |o|
        begin  
          o.force_encoding("UTF-8") if o.is_a?(String) && o.respond_to?(:force_encoding)
        rescue
          Rails.logger.debug ":::: encoding error in Marshal load patch...."
        end
        other_proc.call(o) if other_proc
        o
      end
      load_without_utf8_enforcement(object, @utf8_proc)
    end
    alias_method_chain :load, :utf8_enforcement
  end
end

class String
  def map
    [self]
  end
  def to_a
    [self]
  end
end

# TODO-RAILS3 need to cross check
# Make sure the logger supports encodings properly.
# https://developer.uservoice.com/blog/2012/03/04/how-to-upgrade-a-rails-2-3-app-to-ruby-1-9-3/
# module ActiveSupport
#   class BufferedLogger
#     def add(severity, message = nil, progname = nil, &block)
#       return if @level > severity
#       message = (message || (block && block.call) || progname).to_s
 
#       # If a newline is necessary then create a new message ending with a newline.
#       # Ensures that the original message is not mutated.
#       message = "#{message}\n" unless message[-1] == ?\n
#       message = message.force_encoding(Encoding.default_external) if message.respond_to?(:force_encoding)
#       buffer << message
#       auto_flush
#       message
#     end
#   end
# end
