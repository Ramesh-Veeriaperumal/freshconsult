class Sanitize
  module Config
    POST_WHITELIST = {
      :elements => HTML_RELAXED[:elements] + ['iframe'],
      :attributes => {
        'iframe' => ['src', 'width', 'height', 'frameborder', 'allowfullscreen']
      }.merge(HTML_RELAXED[:attributes]),
<<<<<<< HEAD
=======
      :add_attributes => HTML_RELAXED[:add_attributes],
>>>>>>> origin/prestaging
      :protocols => {
        'iframe' => {'src'  => ['http', 'https', :relative]}
      }.merge(HTML_RELAXED[:protocols]),
      :remove_contents => HTML_RELAXED[:remove_contents],
      :transformers => lambda do |env|

        node      = env[:node]
        node_name = env[:node_name]

        return unless node_name == 'iframe'

        uri = URI.parse(node['src'])

<<<<<<< HEAD
        node.unlink if uri.host == Account.current.full_domain || Account.current.portals.map(&:portal_url).compact.include?(uri.host)
=======
        node.unlink if uri.host.blank? || uri.host == Account.current.full_domain || Account.current.portals.map(&:portal_url).compact.include?(uri.host)
>>>>>>> origin/prestaging
      end
    }
  end
end
