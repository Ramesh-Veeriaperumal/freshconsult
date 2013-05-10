# This file is for methods meant to bridge Ruby 1.8 and Ruby 1.9 code

class RubyBridge

  # This is an attempt to fix issues with strings that are SafeBuffers breaking URI.escape and RightAws::AwsUtils.URLencode
  def self.regular_string(s)
    if RUBY_VERSION >= '1.9'
      (s.nil? || s.class.to_s == 'String') ? s : s.to_s.to_str
      # do not check is_a?(String) here since ActiveSupport::SafeBuffer and ActiveSupport::OutputBuffer return true
    else
      s.to_s
    end
  end

  # for reference, see http://www.zendesk.com/blog/upgrade-the-road-to-1-9
  def self.force_utf8_encoding(str)
    if str.is_a?(String) && str.respond_to?(:force_encoding)
      str = str.dup if str.frozen?

      str.force_encoding(Encoding::UTF_8)

      if !str.valid_encoding?
        #logger.warn("encoding: forcing invalid UTF-8 string; text is #{str}")
        str.encode!(Encoding::UTF_8, Encoding::ISO_8859_1)
      end
    end

    str
  end

  # for reference, see http://www.zendesk.com/blog/upgrade-the-road-to-1-9
  def self.force_binary_encoding(str)
    if str.is_a?(String) && str.respond_to?(:force_encoding)
      str = str.dup if str.frozen?

      str.force_encoding(Encoding::BINARY)
    end

    str
  end

  # Encodes a string from encoding "from" to encoding "to" in
  # a way that works for both ruby 1.8 and 1.9
  def self.convert_string_encoding(to, from, str)
    if "1.9".respond_to?(:force_encoding)
      str = str.dup if str.frozen?
      str.encode(to, from, :undef => :replace)
    else
      require 'iconv'
      Iconv.conv(to, from, str)
    end
  end

end