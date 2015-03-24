 module AttachmentHelper


  def attachment_container(attachment, show_delete, page, note_id=nil)
    unless attachment.empty?
      output = ""
      output << %(<div class="attachment_wrapper mb20">)
      output << %(<ul class="attachment_list">)

      attachment.each do |attached|
        output << attachment_list(attached, show_delete, page, note_id)
      end

      output << %(</ul>)
      output << %(</div>)
      output.html_safe
    end
  end

  def attachment_list(attached, show_delete, page, note_id, custom_delete_link = nil)
    unless attached.new_record?
      output = ""
      output << %(<li class="attachment list_element" id="#{ dom_id(attached) }">)
      output << %(<div>)

      if show_delete
        if (page == "article")
          output << attachment_delete_link(custom_delete_link || helpdesk_attachment_path(attached))
        elsif (page == "cloud_file")
          output << attachment_delete_link(custom_delete_link || helpdesk_cloud_file_path(attached))
        elsif (page == "ticket")
          output << attachment_delete_link(attachment_unlink_path(attached, note_id))
        else
          output << %(<span>)
          output << link_to("",'javascript:void(0)',:class => "delete mr10 #{ page }", :id =>"#{attached.id.to_s}")
          output << %(</span>)
        end
      end

      output << attached_icon(attached, page)

      output << %(<div class="attach_content">)

      if(page == "cloud_file")
        filename = attached.filename || URI.unescape(attached.url.split('/')[-1])
        output << link_to( h(filename.truncate(15)), attached.url , :target => "_blank", :title => h(filename))
        output << %(<span class="file-size cloud-file"></span>)
      else
        size = number_to_human_size attached.content_file_size
        output << content_tag( :div,link_to(h(attached.content_file_name.truncate(23)), attached, :target => "_blank"), :class => "ellipsis")
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
      if (page == "cloud_file")
          output << content_tag(:div, '', :class => "file-types-#{attached.provider}")
      else
        if attached.image?
          output << image_tag(attached.expiring_url(:thumb), :class => "image",
                                :alt => attached.content_file_name,
                                :onerror => "default_image_error(this)",
                                :"data-type" => "attachment"
                                )
        else
          extname = attached.content_file_name.split('.')[-1] || ""

          if(extname != "" && extname.size <= 4 )
            output << content_tag( :div, content_tag( :span, extname ,:class => "file-type"), :class => 'attachment-type')
          else
            output << content_tag( :div, content_tag( :span ), :class => 'attachment-type')
          end

        end
      end
      output.html_safe
  end

  def attachment_delete_link path_url
    link_to "", path_url,
            :method => 'delete',
            :class =>"delete mr10",
            :confirm => t('attachment_delete'),
            :remote => true
  end

  def attachment_unlink_path(attachment, note_id = nil)
    (attachment.attachable_type != "Account" or note_id.blank?) ?
            helpdesk_attachment_path(attachment) :
            unlink_shared_helpdesk_attachment_path(attachment, {:note_id => note_id})
  end


end
