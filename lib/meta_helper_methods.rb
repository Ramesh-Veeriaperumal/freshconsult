module MetaHelperMethods
  
  def metainfo(ticket)
    meta = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"]) 
    return "" if meta.blank?
    unless @ticket.mobihelp?
      meta = YAML::load(meta.body) 
      meta['user_agent'] = UserAgent.parse(meta['user_agent']) if meta['user_agent'].present?
    end
    metainfo_element(meta, ticket)
  end

  def metainfo_element(meta, ticket)
    content = []
    content << "<div class='meta-info'>"
    content << user_agent_element(meta['user_agent']) if meta['user_agent'].present?
    content << meta_referrer_element(meta['referrer']) if meta['referrer'].present?
    content << meta.body[1..-4].gsub('"',' ').gsub(",","<br /> ") if ticket.mobihelp?
    content << "</div>"
    content_tag(:span, t("helpdesk.tickets.show.meta"), 
          :class => "meta_icon", :rel => 'hover-popover', 
          "data-widget-container" => 'ticket_meta_info') +
      content_tag(:textarea, content.join("").html_safe, 
          :class => 'hide', :id => 'ticket_meta_info')
  end

  def user_agent_element(user_agent)
    %( <div>
          <span class="meta-browser browser-#{user_agent_browser(user_agent)}">Browser</span>
          <label>#{user_agent.browser} #{user_agent.version}
        </div>
        <div>
          <span class="meta-os os-#{user_agent_os(user_agent)}">OS</span>
          <label>#{user_agent.os} </label>
        </div>
      )
  end

  def user_agent_os(user_agent)
    ['windows', 'mac', 'linux', 'android' ].each do |v|
      return v if user_agent.os.downcase.include?(v)
    end
  end
  
  def user_agent_browser(user_agent)
    ['chrome', 'firefox', 'internet-explorer', 'safari', 'opera'].each do |v|
      return v if user_agent.browser.downcase.gsub(' ','-').include?(v)
    end
  end

  def meta_referrer_element(referrer)
    %(<div>
        <span class="meta-referrer tooltip" title="Referring page">Referring Page</span>
        <label>
          <a href="#{referrer}" target="_blank" class="tooltip" title="#{referrer}">
            #{short_referrer(referrer)}
          </a>
        </label>
      </div>
    )
  end

  def short_referrer(url)
    truncate(URI.parse(url).path, 20)
  end

end