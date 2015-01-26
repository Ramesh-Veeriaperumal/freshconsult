class Sanitize
  module Config
    ARTICLE_WHITELIST = {
      :elements => HTML_RELAXED[:elements] + ['object', 'param', 'embed', 'canvas', 'video', 'track'],
      :attributes => {
        :all => HTML_RELAXED[:attributes][:all] + ['name'],
        'iframe' => HTML_RELAXED[:attributes]['iframe'] + ['align'],
        'audio' => HTML_RELAXED[:attributes]['audio'] + ['src', 'crossorigin', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted'],
        'source' => HTML_RELAXED[:attributes]['source'] + ['media'],
        'object' => ['type', 'data', 'height', 'width', 'typemustmatch', 'form', 'classid', 'codebase'],
        'param' => ['value'],
        'embed' => [
                    'src', 'type', 'width', 'height',
                    'flashvars', 'base', 'hidden', 'target',
                    'seamlesstabbing', 'allowFullScreen', 'swLiveConnect', 'pluginspage', 'allowScriptAccess',
                    'autostart', 'loop', 'playcount', 'volume', 'controls', 'controller', 'pluginurl', 'mastersound',
                    'startime', 'endtime', 'vspace', 'hspace', 'palette'
                    ],
        'video' => ['src', 'width', 'height', 'crossorigin', 'poster', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted', 'controls'],
        'track' => ['kind', 'src', 'srclang', 'label', 'default']
      }.merge(HTML_RELAXED[:attributes].except('iframe','object','param','embed','video','audio','source','track', :all)),

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
          :elements => ARTICLE_WHITELIST[:elements],
          :attributes => ARTICLE_WHITELIST[:attributes].merge({node.name => (ARTICLE_WHITELIST[:attributes][node.name] || []) + data_attrs.collect(&:name) }),
          :protocols => ARTICLE_WHITELIST[:protocols],
          :remove_contents => ARTICLE_WHITELIST[:remove_contents]
        })
        
        {:node_whitelist => [node]}
      end
    }
  end
end
