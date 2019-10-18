class Sanitize
  module Config
    SANDBOX_BLACKLIST = %w(allow-pointer-lock allow-popups allow-modals allow-top-navigation).freeze
    ARTICLE_WHITELIST = {
      :elements => HTML_RELAXED[:elements] + ['iframe', 'object', 'param', 'embed', 'canvas', 'video', 'track'],
      :attributes => {
        :all => HTML_RELAXED[:attributes][:all] + ['name'],
        'iframe' => ['src', 'width', 'height', 'frameborder', 'allowfullscreen', 'align', 'sandbox'],
        'pre' => HTML_RELAXED[:attributes]['pre'] + ['contenteditable'],
        'audio' => HTML_RELAXED[:attributes]['audio'] + ['src', 'crossorigin', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted'],
        'source' => HTML_RELAXED[:attributes]['source'] + ['media'],
        'object' => ['type', 'height', 'width', 'typemustmatch', 'form', 'classid', 'codebase'],
        'param' => ['value'],
        'li' => ['value'],
        'embed' => [
                    'src', 'type', 'width', 'height',
                    'flashvars', 'base', 'hidden', 'target',
                    'seamlesstabbing', 'allowfullscreen', 'swliveconnect', 'pluginspage', 'allowscriptaccess',
                    'autostart', 'loop', 'playcount', 'volume', 'controls', 'controller', 'pluginurl', 'mastersound',
                    'startime', 'endtime', 'vspace', 'hspace', 'palette'
                    ],
        'video' => ['src', 'width', 'height', 'crossorigin', 'poster', 'preload', 'autoplay', 'mediagroup', 'loop', 'muted', 'controls', 'playsinline'],
        'track' => ['kind', 'src', 'srclang', 'label', 'default'],
        'font' => HTML_RELAXED[:attributes]['font'] + ['size', 'face'],
        'td' => HTML_RELAXED[:attributes]['td'] + ['bgcolor'],
        'table' => HTML_RELAXED[:attributes]['table'] + ['bgcolor'],
        'th' => HTML_RELAXED[:attributes]['th'] + ['bgcolor'],
        'tr' => ['bgcolor'],
        'tbody' => ['bgcolor']
      }.merge(HTML_RELAXED[:attributes].except('object','param','embed','video','audio','source','track','font', 'td', :all)),

      :protocols => {
        'img' => { 'src' => HTML_RELAXED[:protocols]['img']['src'] + ['data', 'cid'] },
        'embed' => {'src'  => ['http', 'https']},
        'video' => {'src'  => ['http', 'https']},
        'iframe' => {'src'  => ['http', 'https', :relative]}
      }.merge(HTML_RELAXED[:protocols].except('img')),
      :remove_contents => HTML_RELAXED[:remove_contents],
      :transformers => lambda do |env|
        node      = env[:node]

        return if env[:is_whitelisted] || !node.element? || ARTICLE_WHITELIST[:elements].exclude?(node.name)

        if node.name == 'iframe'
          uri = URI.parse(node['src'])
          if uri.host.blank? || uri.host == Account.current.full_domain || Account.current.portals.map(&:portal_url).compact.include?(uri.host)
            node.unlink
            return
          end

          node['sandbox'] ||= "allow-scripts allow-forms allow-same-origin allow-presentation"
          node['sandbox'].gsub!(Regexp.union(SANDBOX_BLACKLIST), '')
        end

        data_attrs = node.attribute_nodes.select{|a_n| a_n.name =~ /^data-/ }

        return if data_attrs.empty?

        Sanitize.node!(node, {
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
