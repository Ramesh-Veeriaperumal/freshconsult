module Helpdesk::NotesHelper

include Helpdesk::NoteActions

def is_twitter_dm?(note, ticket)
  ticket.twitter? && note.tweet && note.tweet.is_dm?
end

def is_facebook_message?(note, ticket)
  ticket.facebook? && note.fb_post && note.fb_post.message?
end

def note_lock_icon(note, ticket)
  icon_class = ""
  if note.broadcast_note?
    icon_class = "ficon-broadcast-tracker fsize-20 muted"
  elsif note.private_note?  || note.fwd_email? || note.reply_to_forward?
    icon_class = "comment-lock"
  elsif is_twitter_dm?(note, ticket)
    icon_class = "ficon-twitter-lock fsize-21 muted"
  elsif is_facebook_message?(note, ticket)
    icon_class = "ficon-facebook-lock fsize-21 muted"
  end
  content_tag(:span, "", :class => icon_class).html_safe
end

def load_agent_text responder
  responder && (responder.id != current_user.id) ? "#{responder.name} <#{responder.email}>" : nil
end

end
