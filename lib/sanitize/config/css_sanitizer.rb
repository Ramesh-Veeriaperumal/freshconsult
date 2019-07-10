# List of CSS properties to be blacklisted in the HTML nodes

module Sanitize::Config::CSSSanitizer
  # list of not allowed CSS properties
  CSS_BLACKLIST = %w[animation position transform transition voice volume].freeze

  # list of properties which dont allow negative values
  BLACKLISTED_NEGATIVE_PROPERTIES = %w[margin].freeze

  # logic to remove all blacklisted styles
  def self.sanitize_styles(node)
    # check if node has style attribute, sanitize the CSS properties.
    return unless node.element? && node.key?('style')

    styles = node['style'].split(/\;/)
    styles = styles.select do |style|
      property_name = style.split(':')[0].strip
      if BLACKLISTED_NEGATIVE_PROPERTIES.any? { |prop| property_name.start_with?(prop) }
        !style.split(':')[1].include? '-'
      else
        !CSS_BLACKLIST.any? { |prop| property_name.start_with?(prop) }
      end
    end
    node['style'] = styles.join("\;")
  end
end