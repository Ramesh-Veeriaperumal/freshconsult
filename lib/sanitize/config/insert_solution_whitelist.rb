class Sanitize
  module Config
    INSERT_SOLUTION_WHITELIST = HTML_RELAXED.merge({
      :transformers => lambda do |env|

        node      = env[:node]
        node_name = env[:node_name]
        
        if node_name == 'iframe'
          node.name = 'a'
          node['href'] = node['src']
          node.content = node['src']
        end
      end
    })
  end
end
