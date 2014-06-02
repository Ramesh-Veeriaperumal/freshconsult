 module AttachmentHelper

  def attachment_container(attachment, show_delete, page, note_id=nil)
    output = ""
    output << %(<div class="attachment_wrapper mb20">)
    output << %(<ul class="attachments attachment_list">)

    attachment.each do |attached|
      output << attachment_list(attached, show_delete, page, note_id)
    end

    output << %(</ul>)
    output << %(</div>)
    output.html_safe
  end

  def attachment_list(attached, show_delete, page, note_id)
    unless attached.new_record?
      output = ""
      output << %(<li class="attachment list_element" id="#{ dom_id(attached) }">)
      output << %(<div>)

      if show_delete
        if (page == "article")
          output << attachment_delete_link(helpdesk_attachment_path(attached))
        elsif (page == "dropbox")
          output << attachment_delete_link(helpdesk_dropbox_path(attached))
        elsif (page == "ticket")
          output << attachment_delete_link(attachment_unlink_path(attached, note_id))
        else
          output << %(<span>)
          output << link_to(image_tag("delete_icon.png", :alt => t('delete')),'javascript:void(0)',:class => "delete mr10 #{ page }", :id =>"#{attached.id.to_s}")
          output << %(</span>)
        end
      end

      output << attached_icon(attached, page)

      output << %(<div class="attach_content">)

      if(page == "dropbox")
        filename = attached.url.split('/')[-1]
        output << link_to( h(truncate(filename,15)), attached.url , :popup => true, :title => h(filename))
        output << %(<span class="file-size">( #{h("dropbox link")} )</span>)
      else
        size = number_to_human_size attached.content_file_size 
        output << content_tag( :div,link_to(truncate(h(attached.content_file_name), { :length => 23 }), attached, :popup => true),:class => "ellipsis")
        output << %(<span class="file-size">( #{size} )</span>)
      end

      output << %(</div>)
      output << %(</div>)
      output << %(</li>)
      output.html_safe
    end
  end

  def attached_icon(attached, page)
    output = ""
      if (page == "dropbox")
          output << content_tag(:div, '', :class => "file-types-dropbox")
      else    
        if attached.image?
          output << image_tag(attached.expiring_url(:thumb), :class => "image", :alt => attached.content_file_name)
        else
          extname = attached.content_file_name.split('.')[-1] || ""

          extname = extname.downcase
          # Converting 4 letter into 3 letter extensions
          letter4 = {"html" => "htm"}
          extname = letter4[extname] if letter4[extname].present?

          extname = (["asf", "ai", "apk", "bmp", "avi", "cdr", "chm", "csv",
          "dmg", "dwg", "eps", "exe", "fla", "flv", "gz","htm", 
          "iso", "jar", "jpg", "js", "key", "m4a", "mdb", "mid", 
          "mov", "mp3", "mp4", "mpg", "msi", "otf", "pdf", "php", 
          "png", "ppt", "pptx", "html", "ps", "psd", "pub", "rar", 
          "rb", "rtf", "sql", "svg", "swf", "tex", "tga", "tif", "ttf", "txt",
          "vcf", "wav", "wma", "wmv", "xls", "xml", "doc",
          "zip", "log" , "gif" , "pem", "css"].include?(extname)) ? extname : "def" 

          output << content_tag( :div, content_tag( :span, extname ,:class => "file-type"), :class => 'attachment-type')
        end 
      end
      output.html_safe
  end

  def attachment_delete_link path_url
    link_to_remote(image_tag("delete_icon.png", :alt => t('delete')), :url => path_url, 
                  :method => 'delete',
                  :html => { :class =>" delete mr10" },
                  :confirm => t('attachment_delete')) 
  end

  def attachment_unlink_path(attachment, note_id = nil)
    (attachment.attachable_type != "Account" or note_id.blank?) ?
            helpdesk_attachment_path(attachment) : 
            unlink_shared_helpdesk_attachment_path(attachment, {:note_id => note_id})
  end

end  