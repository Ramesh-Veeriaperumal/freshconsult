module MetaHelperMethods
  
  def metainfo(ticket)
    meta = ticket.notes.find_by_source(Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["meta"]) 
    return "" if meta.blank?
    unless @ticket.mobihelp?
      begin
        meta = YAML::load(meta.body) 
      rescue
        Rails.logger.info "Error parsing metainfo as YAML"
        Rails.logger.info "Meta:: #{meta.body}"
        return ""
      end
      meta['user_agent'] = UserAgent.parse(meta['user_agent']) if meta['user_agent'].present?
    end
    metainfo_element(meta, ticket)
  end

  def metainfo_element(meta, ticket)
    content = []
    content << "<div class='meta-info'>"
    content << "#{user_agent_browser(meta['user_agent'])} #{user_agent_os(meta['user_agent'])}" if meta['user_agent'].present?
    content << meta_referrer_element(meta['referrer']) if meta['referrer'].present?
    content << meta.body[1..-4].gsub('"',' ').gsub(",","<br /> ") if ticket.mobihelp?
    content << "</div>"
    content_tag(:span, t("helpdesk.tickets.show.meta"), 
          :class => "meta_icon", :rel => 'hover-popover', 
          "data-widget-container" => 'ticket_meta_info') +
      content_tag(:textarea, content.join("").html_safe, 
          :class => 'hide', :id => 'ticket_meta_info')
  end

  def user_agent_browser(user_agent)
    return "" if user_agent.browser.blank?
    %( <div>
          <span class="meta-browser browser-#{browser_shorthand(user_agent.browser)}">Browser</span>
          <label>#{user_agent.browser} #{user_agent.version}</label>
        </div>
        <div class="clearfix"></div>
    )
  end

  def browser_shorthand(browser)
    ['chrome', 'firefox', 'internet-explorer', 'safari', 'opera'].each do |v|
      return v if browser.downcase.gsub(' ','-').include?(v)
    end
  end

  def user_agent_os(user_agent)
    return "" if user_agent.os.blank?
    %(  <div>
          <span class="meta-os os-#{os_shorthand(user_agent.os)}">OS</span>
          <label>#{user_agent.os} </label>
        </div>
        <div class="clearfix"></div>
      )
  end

  def os_shorthand(os)
    ['windows', 'mac', 'linux', 'android' ].each do |v|
      return v if os.downcase.include?(v)
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
      <div class="clearfix"></div>
    )
  end

  def short_referrer(url)
    begin
      truncate(URI.parse(url).path, 20)
    rescue
      truncate(url, 20)
    end
  end

end