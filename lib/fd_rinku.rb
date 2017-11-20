# For Rinku : https://github.com/vmg/rinku
# Usage : 
# FDRinku.auto_link(text, {:mode => :urls, :attr => 'rel="noreferrer"'})

module FDRinku

  MODES = [:all, :urls, :email_addresses]

  DEFAULT_OPTIONS = {
    :mode => :urls,
    :attr => nil,
    :skip => nil,
    :short_domains => 1
  }

  AUTO_LINK_RE = %r{
      (?: ((?:notes):)// )
      [^\s<\u00A0"]+
    }ix

  # regexps for determining context, used high-volume
  AUTO_LINK_CRE = [/<[^>]+$/, /^[^>]*>/, /<a\b.*?>/i, /<\/a>/i]

  BRACKETS = { ']' => '[', ')' => '(', '}' => '{' }

  WORD_PATTERN = RUBY_VERSION < '1.9' ? '\w' : '\p{Word}'

  def self.auto_link(text, options = {}, &block)
    return text if text.blank? or options.nil?

    options[:mode] = :all if 
      options[:mode].present? and !MODES.include?(options[:mode])
    options.reverse_merge!(DEFAULT_OPTIONS)

    text = auto_link_custom_urls text

    Rinku.auto_link(
      text,
      options[:mode],
      options[:attr],
      options[:skip],
      options[:short_domains],
      &block
    )
  end

  # The below two methods are copied and slightly modified from the gem, https://github.com/tenderlove/rails_autolink by rails_core_dev

  def self.auto_linked?(left, right)
    (left =~ AUTO_LINK_CRE[0] and right =~ AUTO_LINK_CRE[1]) or
      (left.rindex(AUTO_LINK_CRE[2]) and $' !~ AUTO_LINK_CRE[3])
  end

  def self.auto_link_custom_urls(text, html_options = {}, options = {})
    link_attributes = html_options.stringify_keys
    text.gsub(AUTO_LINK_RE) do
      scheme, href = $1, $&
      punctuation = []

      if auto_linked?($`, $')
        # do not change string; URL is already linked
        href
      else
        # don't include trailing punctuation character as part of the URL
        while href.sub!(/[^#{WORD_PATTERN}\/-=&]$/, '')
          punctuation.push $&
          if opening = BRACKETS[punctuation.last] and href.scan(opening).size > href.scan(punctuation.last).size
            href << punctuation.pop
            break
          end
        end

        link_text = block_given?? yield(href) : href
        href = 'http://' + href unless scheme

        unless options[:sanitize] == false
          link_text = RailsFullSanitizer.sanitize(link_text)
          href      = RailsFullSanitizer.sanitize(href)
        end
        ActionController::Base.helpers.content_tag(:a, link_text, link_attributes.merge('href' => href), !!options[:sanitize]) + punctuation.reverse.join('')
      end
    end
  end

end