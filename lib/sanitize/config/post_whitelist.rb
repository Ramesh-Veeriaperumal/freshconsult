class Sanitize
  module Config
    CODE_SNIPPET_LANGUAGES = %w(html css js sass xml ruby php java csharp cpp objc perl python vbnet sql text)
    POST_WHITELIST = {
      :elements => HTML_RELAXED[:elements] + ['iframe'],
      :attributes => {
        'iframe' => ['src', 'width', 'height', 'frameborder', 'allowfullscreen']
      }.merge(HTML_RELAXED[:attributes]),
      :add_attributes => HTML_RELAXED[:add_attributes],
      :protocols => {
        'iframe' => {'src'  => ['http', 'https', :relative]}
      }.merge(HTML_RELAXED[:protocols]),
      :remove_contents => HTML_RELAXED[:remove_contents],
      :transformers => lambda do |env|

        node      = env[:node]
        node_name = env[:node_name]

        if node_name == 'pre' && !CODE_SNIPPET_LANGUAGES.include?(node.attributes['data-code-brush'].value)
          node.attributes['data-code-brush'].value = ''
        end

        return unless node_name == 'iframe'

        uri = URI.parse(node['src'])

        node.unlink if uri.host.blank? || uri.host == Account.current.full_domain || Account.current.portals.map(&:portal_url).compact.include?(uri.host)
      end
    }
  end
end
