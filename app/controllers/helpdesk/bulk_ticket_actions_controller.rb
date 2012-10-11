require 'fastercsv'

class Helpdesk::BulkTicketActionsController < ApplicationController
  include ActionView::Helpers::TextHelper
  include ParserUtil
  include HelpdeskControllerMethods  

  before_filter { |c| c.requires_permission :manage_tickets }

  before_filter :load_multiple_items, :validate_attachment_size, :only => :update_multiple

  def update_multiple
    params[nscname][:custom_field].delete_if {|key,value| value.blank? } unless 
              params[nscname][:custom_field].nil?
    reply_content = params[:helpdesk_note][:body_html]
    @items.each do |item|
      params[nscname].each do |key, value|
        item.send("#{key}=", value) if !value.blank? and item.respond_to?("#{key}=")
      end
      reply_multiple reply_content, item
      item.save
    end
    flash[:notice] = render_to_string(:inline => t("helpdesk.flash.tickets_update", 
      :tickets => get_updated_ticket_count ))
    redirect_to helpdesk_tickets_path
  end

  protected

    def reply_multiple reply_content, item
      return if reply_content.blank?
      params[:helpdesk_note][:body_html] = Liquid::Template.parse(reply_content).render(
        'ticket' => item, 'helpdesk_name' => item.portal_name)
      note = item.notes.build(params[:helpdesk_note])
      build_attachments note, :helpdesk_note
      send_reply_email note if note.save
    end

    def send_reply_email note
      Helpdesk::TicketNotifier.send_later(:deliver_reply, note.notable, note);    
    end

    def get_updated_ticket_count
      pluralize(@items.length, t('ticket_was'), t('tickets_were'))
    end  
    
    def cname
      @cname ||= 'tickets'
    end

    def nscname
      'helpdesk_ticket'
    end

end
