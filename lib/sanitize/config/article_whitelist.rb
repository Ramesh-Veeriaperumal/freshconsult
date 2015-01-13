class Sanitize
  module Config
    ARTICLE_WHITELIST = {
      :elements => HTML_RELAXED[:elements] + ['object', 'param', 'embed', 'canvas', 'video', 'track'],
      :attributes => {
        'iframe' => HTML_RELAXED[:attributes]['iframe'] + ['align'],
        'audio' => HTML_RELAXED[:attributes]['audio'] + ['src', 'crossorigin', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted'],
        'source' => HTML_RELAXED[:attributes]['source'] + ['media'],
        'a' => HTML_RELAXED[:attributes]['a'] + ['name'],
        'object' => ['type', 'data', 'height', 'width', 'typemustmatch', 'form'],
        'param' => ['name', 'value'],
        'embed' => ['src', 'type', 'width', 'height'],
        'video' => ['src', 'width', 'height', 'crossorigin', 'poster', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted', 'controls'],
        'track' => ['kind', 'src', 'srclang', 'label', 'default']
      }.merge(HTML_RELAXED[:attributes].except('iframe','object','param','embed','video','audio','source','track', 'a')),

      :protocols => {
        'img' => { 'src' => HTML_RELAXED[:protocols]['img']['src'] + ['data', 'cid'] }
      }.merge(HTML_RELAXED[:protocols].except('img')),
      :remove_contents => HTML_RELAXED[:remove_contents],
      :transformers => lambda do |env|
        node      = env[:node]
        
        return if env[:is_whitelisted] || !node.element? || ARTICLE_WHITELIST[:elements].exclude?(node.name)

        data_attrs = node.attribute_nodes.select{|a_n| a_n.name =~ /^data-/ }
        
        return if data_attrs.empty?
        
        Sanitize.clean_node!(node, {
          :elements => [node.name],
          :attributes => {node.name => (ARTICLE_WHITELIST[:attributes][node.name] || []) + data_attrs.collect(&:name) },
          :protocols => {node.name => (ARTICLE_WHITELIST[:protocols][node.name] || {}) }
        })
        
        {:node_whitelist => [node]}
      end
    }
  end
end
