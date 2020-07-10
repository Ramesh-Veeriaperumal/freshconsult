class String
  def to_bool
    return true   if self == true   || self =~ (/^(true|t|yes|y|1)$/i)
    return false  if self == false  || self.blank? || self =~ (/^(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end

  def is_number?
    true if Float(self) rescue false
  end

  def tokenize_emoji
    EmojiParser.tokenize(self)
  rescue
    self
  end

  def detokenize_emoji
    EmojiParser.detokenize(self)
  rescue
    self
  end
end

class NullObject < Struct.new(nil)
  def self.instance
    @@null_object ||= NullObject.new
  end
end

module StringExt
#   def brackets_with_translation(*args)
#     args = [underscore.tr(' ', '_').to_sym] if args.empty?
#     return brackets_without_translation(*args) unless args.first.is_a? Symbol
#     Rails.logger.info "::::::::::::::::::::::::::::Some stupid code calling [] on string::::#{caller.join('\n\t')}"
#     self
#   end

#   def self.included(base)
#     base.class_eval do
#       alias :brackets :[]
#       alias_method_chain :brackets, :translation
#       alias :[] :brackets
#     end
#   end

  # PRE-RAILS: This method was overridden in gems/savon-0.9.2/lib/savon/core_ext/string.rb which is dependency for Marketo.
  # Moved Marketo to Autopilot - https://github.com/freshdesk/helpkit/commit/b6bbc413fa9a91c7ac75b25af015e11a049d7c0d
  # On Marketo Removal, there was dependecy on this method, so included here.
  def snakecase
    str = dup
    str.gsub! /::/, '/'
    str.gsub! /([A-Z]+)([A-Z][a-z])/, '\1_\2'
    str.gsub! /([a-z\d])([A-Z])/, '\1_\2'
    str.tr! ".", "_"
    str.tr! "-", "_"
    str.downcase!
    str
  end
end

String.send :include, StringExt
