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
      :remove_contents => HTML_RELAXED[:remove_contents]
    }
  end
end
