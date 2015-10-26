module Portal::Helpers::SolutionsHelper

  def alternate_version_url(lang_code,path,portal=nil)
    portal = current_portal unless portal
    "#{portal.url_protocol}://#{portal.host}/#{lang_code}#{path}" 
  end

  def multilingual_meta_tags(meta)
    meta_tags = []
    meta.each do |lang,url|
      meta_tags << %( <link rel='alternate' hreflang="#{lang}" href="#{url}"/> )
    end
    meta_tags.join('').html_safe
  end
  
end