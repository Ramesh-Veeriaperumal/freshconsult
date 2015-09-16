module Helpdesk::ArchiveNotesHelper

  include Helpdesk::NoteActions
  include Helpdesk::TicketsHelper

  def is_twitter_dm?(note)
    note.tweet && note.tweet.is_dm?
  end

  def is_facebook_message?(note)
    note.fb_post && note.fb_post.message?
  end

end
