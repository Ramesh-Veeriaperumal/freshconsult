 module AttachmentHelper


  def attachment_container(attachment, show_delete, page, item_id=nil)
    unless attachment.empty?
      output = ""
      output << %(<div class="attachment_wrapper mb20">)
      output << %(<ul class="attachment_list">)

      attachment.each do |attached|
        output << attachment_list(attached, show_delete, page, item_id)
      end

      output << %(</ul>)
      output << %(</div>)
      output.html_safe
    end
  end

  def attachment_list(attached, show_delete, page, item_id, custom_delete_link = nil, add_to_reply = false, index = nil)
    multifile_enabled = true
    add_to_reply = add_to_reply && multifile_enabled
    unless attached.new_record?
      output = ""
      output << %(<li class="#{multifile_enabled ? 'addToRply' : ' attachment list_element '}" id="#{ dom_id(attached) }" rel="original_attachment" data-index="#{index}">)
      if multifile_enabled
        output << %(<div class="attachment list_element" id="#{ dom_id(attached) }" data-added=false data-multifile=#{multifile_enabled}> )
      end
      output << %(<div>)

      if show_delete
        if (page == "article" or page == "topic")
          output << attachment_delete_link(custom_delete_link || helpdesk_attachment_path(attached))
        elsif (page == "cloud_file")
          output << attachment_delete_link(custom_delete_link || helpdesk_cloud_file_path(attached))
        elsif (["ticket", "ticket_template"].include? page)
          output << attachment_delete_link(attachment_unlink_path(attached, item_id))
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
        tooltip = filename.size > 15 ? "tooltip" : ""
        output << link_to( h(filename.truncate(15)), attached.url , :target => "_blank", :rel => "noreferrer noopener",
                           :title => h(filename), :class => "#{tooltip}")
        output << %(<span class="file-size cloud-file"></span>)
      else
        size = number_to_human_size attached.content_file_size
        tooltip = attached.content_file_name.size > 15 ? "tooltip" : "" 
        output << content_tag( :div,link_to(h(attached.content_file_name.truncate(15)), attached, :target => "_blank", 
                              :title => h(attached.content_file_name), :class => "#{tooltip}"),
                              :class => "ellipsis")
        output << %(<span class="file-size">( #{size} )</span>)
      end

      output << %(</div>)
      output << %(</div>)
      if(add_to_reply)
         output << %(</div>)
         output << %(<div class="add-attachment-to-conv tooltip" data-original-title="#{I18n.t('multifile_attachments.attach')}" data-location="attachment" data-cloud="#{(page == 'cloud_file')? true:false}" data-attach-id = "#{attached.id.to_s}"><span class="ficon ficon-add-attachment"></span></div>)
      end
      output << %(</li>)
      output.html_safe
    end
  end

  def attached_icon(attached, page)
    output = ""
      if (page == "cloud_file")
          output << content_tag(:div, '', :class => "file-types-#{attached.provider}")
      else
        if attached.image? && attached.has_thumbnail?
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

  def attachment_unlink_path(attachment, item_id = nil)
    (attachment.attachable_type != "Account" or item_id.blank?) ?
      helpdesk_attachment_path(attachment) :
      unlink_shared_helpdesk_attachment_path(attachment, {:item_id => item_id})
  end

  def ticket_page_attachment(attachment)
    ["attachable", "droppable"].each do |name|
      if attachment.respond_to?("#{name}_type") and 
        ["Helpdesk::Note", "Helpdesk::Ticket"].include?(attachment.safe_send("#{name}_type")) 
  
        id = attachment.safe_send("#{name}_id")
        attachments_count = attachment.safe_send(name).all_attachments.size + 
                         attachment.safe_send(name).cloud_files.size
        type = attachment.safe_send("#{name}_type") == "Helpdesk::Note" ? 'note' : 'ticket'
        return {id: id , attachments_count: attachments_count , type: type}
      end
    end
    false
  end
end
