class Integrations::Hootsuite::TicketsController < Integrations::Hootsuite::HootsuiteController

  include Helpdesk::TicketsHelper
  include Facebook::Core::Util
  include Helpdesk::TagMethods
  include Social::Twitter::Common

  before_filter :build_ticket, :only => [:create]
  before_filter :load_object, :only => [:show,:add_note,:add_reply,:append_social_reply,:update]

  def show
    @ticket_notes_total = @ticket.conversation_count
    @ticket_note_all = @ticket.conversation(nil, @ticket_notes_total,
      [:user, :attachments, :schema_less_note, :cloud_files,:note_old_body]).reverse if @ticket_notes_total > 0
    if @ticket.is_twitter? or @ticket.is_facebook?
      @note = Helpdesk::Note.new(:private => false)
      @note_body = Helpdesk::NoteBody.new
    end
    @show_reply = (@ticket.is_twitter?) || (@ticket.is_facebook?) || (@ticket.from_email.present?)
    @ticket_fields = hs_ticket_fields
  end

  def create
    if @ticket.save_ticket
      @path = helpdesk_ticket_url(@ticket)
      render(:partial => "integrations/hootsuite/home/ticket_link_page",:locals => {:already_exist => false})
    else
      @error = true
      @item = @ticket = Helpdesk::Ticket.new
      @ticket_fields = hs_ticket_fields
      render("integrations/hootsuite/home/handle_plugin")
    end
  end
  
  def update
    if @ticket.update_ticket_attributes(params[:helpdesk_ticket])
      update_tags(params[:helpdesk][:tags], true, @ticket) unless params[:helpdesk].blank? or params[:helpdesk][:tags].blank?
      render :json => {:status => "success", :msg => t(:'flash.general.update.success',
        {:human_name => t(:'integrations.hootsuite.ticket.human_name') })}
    else
      render :json => {:status => "failure", :msg => t(:'flash.general.update.failure',
        {:human_name => t(:'integrations.hootsuite.ticket.human_name') })}
    end
  end
  
  def add_note
    note = @ticket.notes.build(
        :note_body_attributes => { :body_html => params[:message] },
        :private => params[:isPrivate],
        :source => Helpdesk::Note::SOURCE_KEYS_BY_TOKEN["note"],
        :account_id => @ticket.account_id,
        :user_id => current_user.id,
      )
    if note.save_note
      respond_to do |format|
        format.js { render "note" }
      end
    else
      render :json => {:status => "failed", :msg => t(:'flash.general.create.failure',
        {:human_name => t(:'integrations.hootsuite.note.human_name') })}
    end
  end

  def add_reply
    note = @ticket.notes.build(
        :note_body_attributes => { :body_html => params[:message] },
        :account_id => @ticket.account_id,
        :user_id => current_user.id,
        :from_email => params[:from],
        :cc_emails => params[:cc],
        :bcc_emails => params[:bcc],
        :private => false
      )
    if note.save_note
      respond_to do |format|
        format.js { render "note" }
      end
    else
      render :json => {:status => "failed", :msg => t(:'flash.general.create.failure',
        {:human_name => t(:'integrations.hootsuite.reply.human_name') })}
    end
  end

  def append_social_reply
    respond_to do |format|
      format.js { render "note" }
    end
  end

  private

  def build_ticket
    params[:helpdesk_ticket][:ticket_body_attributes][:description_html] = params[:helpdesk_ticket][:ticket_body_attributes][:description_html].gsub!(/\r\n|\n/, '<br/>')
    if (params[:tweet_id].present? && params[:helpdesk_ticket][:twitter_id].present?)
      build_tweet_params
    end

    if (params[:fb_profile].present? && params[:post_id].present?)
      build_facebook_params
    end
    @ticket = current_account.tickets.build(params[:helpdesk_ticket])
  end

  def build_tweet_params
    params[:helpdesk_ticket][:tweet_attributes] = {"twitter_handle_id" => params[:twitter_handle_id],"tweet_id" => params[:tweet_id]}
    params[:helpdesk_ticket][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:twitter]
    params[:helpdesk_ticket][:requester] = get_twitter_user(params[:helpdesk_ticket][:twitter_id],params[:image])
  end

  def build_facebook_params
    @account = current_account
    @rest = Koala::Facebook::API.new(current_account.facebook_pages.find_by_id(params[:fb_page_id]).page_token)
    params[:helpdesk_ticket][:requester] = facebook_user(params[:fb_profile].to_hash)
    params[:helpdesk_ticket][:fb_post_attributes] = {
        :post_id          => params[:post_id],
        :facebook_page_id => params[:fb_page_id],
        :parent_id        => nil,
        :post_attributes => {
          :can_comment => true,
          :post_type   => Facebook::Constants::POST_TYPE_CODE[:post]
        }
      }
    params[:helpdesk_ticket][:source] = TicketConstants::SOURCE_KEYS_BY_TOKEN[:facebook]
  end

  private

  def load_object
    @ticket = scoper.find_by_display_id(params[:id])
    throw_error if @ticket.blank?
  end

  def scoper
    current_account.tickets.assigned_to(current_user).visible
  end

  def throw_error
    if request.xhr?
      render :json => {:status => "failed", :msg => t(:'integrations.hootsuite.access_denied_error.message')} and return
    else
      render(:partial => "access_denied") and return
    end
  end
end