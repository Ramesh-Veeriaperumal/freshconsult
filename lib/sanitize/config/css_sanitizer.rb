# List of CSS properties to be blacklisted in the HTML nodes

module Sanitize::Config::CSSSanitizer
  # blacklisted values in each property
  BLACKLISTED_VALUES_IN_PROPERTIES = {
    'animation'             => [],
    '-webkit-animation'     => [],
    '-webkit-animation-name'=> [],
    'animation-name'        => [],
    'z-index'               => [],
    'transform'             => [],
    '-webkit-transform'     => [],
    '-ms-transform'         => [],
    'transition'            => [],
    '-webkit-transition'    => [],
    '-o-transition'         => [],
    'position'              => ['absolute', 'fixed', 'sticky'],
    'margin'                => ['-'],
    'margin-top'            => ['-'],
    'margin-right'          => ['-'],
    'margin-bottom'         => ['-'],
    'margin-left'           => ['-'],
    'top'                   => ['-'],
    'right'                 => ['-'],
    'bottom'                => ['-'],
    'left'                  => ['-']
  }.freeze

  # logic to remove all blacklisted sanitize_styles
  def self.sanitize_styles(node)
    # check if node has style attribute, sanitize the CSS properties.
    return unless node.element? && node.key?('style')

    should_log = false
    styles = node['style'].split(/\;/)
    sanitised_styles = styles.select do |style|
      properties = style.split(':')
      next if properties[0].blank? || properties[1].blank?

      property_name = properties[0].downcase.strip
      value_name = properties[1].downcase.strip
      BLACKLISTED_VALUES_IN_PROPERTIES[property_name] ? !(BLACKLISTED_VALUES_IN_PROPERTIES[property_name].empty? || BLACKLISTED_VALUES_IN_PROPERTIES[property_name].any? { |prop| should_log = value_name.include?(prop) }) : true
    end
    # Adding logs if "Node" is sanitized for debugging any issue because of sanitization
    Rails.logger.info "Node before Sanitization: #{node}" if should_log
    node['style'] = sanitised_styles.join("\;")
  rescue StandardError
    Rails.logger.error "Error in CSS Sanitization: #{node['style']} "
  end
end
