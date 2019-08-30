# Remove bgcolor css property and add the color to background property
module Sanitize::Config::BgColorSanitizer
  # logic to remove bgcolor and add it to background property
  def self.bg_color_sanitizer(node)
    # check if node is a table
    return if !node.element? || node.name != 'table'

     if node.attributes.include?('bgcolor')
      value_bg_color = node.attributes['bgcolor'].value
      node.attributes['bgcolor'].remove
      if node.attributes['style']
        node.attributes['style'].value = node.attributes['style'].value << ';background-color:' << value_bg_color
      else
        node['style'] = ''
        node.attributes['style'].value = node.attributes['style'].value << 'background-color:' << value_bg_color
      end
      return node
    end
  rescue StandardError
    Rails.logger.error "Error in BG Color Sanitization: #{node['style']}"
  end
end