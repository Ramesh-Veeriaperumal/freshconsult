module Helpdesk::CannedResponsesHelper
  def attachment_classic_view att
    %( <div class="item">
        #{escape_javascript(att.content_file_name)} -
        <a href="#" class="removefile" onclick="jQuery(this).parent().remove(); return false;" >remove</a>
        <input type="hidden" value="#{att.id}" name="shared_attachments[]" class="ca" />
      </div>)
  end
  
  def attachment_new_view att
    %( <div class="item">
        <a href="#" class="removefile attachment-close" onclick="jQuery(this).parent().remove(); return false;" ></a>
        <a href="#"> #{escape_javascript(att.content_file_name)} </a>
        <input type="hidden" value="#{att.id}" name="shared_attachments[]" class="ca" />
      </div>)
  end
end
