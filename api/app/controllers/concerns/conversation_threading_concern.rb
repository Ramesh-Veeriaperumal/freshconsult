# frozen_string_literal: true

module ConversationThreadingConcern
  extend ActiveSupport::Concern

  NOTE_ANCESTRY = '%{ticket_fb_post_id}/%{note_fb_post_id}'

  def parent_conversations_scoper
    case true
    when @ticket.facebook?
      fb_parent_conversations_scoper
    else
      []
    end
  end

  def child_conversations_scoper
    case true
    when @ticket.facebook?
      fb_child_conversations_scoper
    else
      []
    end
  end

  def fb_parent_conversations_scoper
    ancestry = fetch_fb_post_ancestry(@ticket)
    @ticket.notes.parent_facebook_comments(ancestry, conditional_preload_options, order_conditions)
  end

  def fb_child_conversations_scoper
    ancestry = fetch_fb_post_ancestry(@ticket, parent_id)
    @ticket.notes.child_facebook_comments(ancestry, conditional_preload_options, order_conditions)
  end

  def child_conversations_count
    note_ancestry_mapping = fetch_fb_post_ancestry_ids
    count_ancestry_mapping = current_account.facebook_posts.total_child_posts(note_ancestry_mapping.keys)

    count_ancestry_mapping.each_with_object({}) do |fb_post, h|
      h[note_ancestry_mapping[fb_post.ancestry]] = fb_post.child_posts_count
    end
  end

  private

    def parent_conversations?
      params[:parent].present? && params[:parent].to_bool && ticket.threading_enabled?
    end

    def child_conversations?
      params[:parent_id].present?
    end

    def parent_id
      params[:parent_id]
    end

    def fetch_fb_post_ancestry(ticket, note_id = nil)
      if note_id.blank?
        ticket.fb_post.id.to_s
      else
        note_fb_post = current_account.facebook_posts.where(postable_type: 'Helpdesk::Note', postable_id: note_id).last
        format(NOTE_ANCESTRY, ticket_fb_post_id: ticket.fb_post.id, note_fb_post_id: note_fb_post.id)
      end
    end

    def fetch_fb_post_ancestry_ids
      @items.each_with_object({}) do |note, h|
        h[format(NOTE_ANCESTRY, ticket_fb_post_id: @ticket.fb_post.id, note_fb_post_id: note.fb_post.id)] = note.id if note.fb_post.present?
      end
    end
end
