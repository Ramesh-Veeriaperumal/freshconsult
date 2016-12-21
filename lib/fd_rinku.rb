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

  def self.auto_link(text, options = {}, &block)
    return text if text.blank? or options.nil?

    options[:mode] = :all if 
      options[:mode].present? and !MODES.include?(options[:mode])
    options.reverse_merge!(DEFAULT_OPTIONS)

    Rinku.auto_link(
      text,
      options[:mode],
      options[:attr],
      options[:skip],
      options[:short_domains],
      &block
    )
  end

end