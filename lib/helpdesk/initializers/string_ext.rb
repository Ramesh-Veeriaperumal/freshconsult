class String
  def to_bool
    return true   if self == true   || self =~ (/(true|t|yes|y|1)$/i)
    return false  if self == false  || self.blank? || self =~ (/(false|f|no|n|0)$/i)
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

# module StringExt
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
# end

# String.send :include, StringExt