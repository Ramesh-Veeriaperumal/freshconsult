namespace :attachment_cleanup do
  desc "Cleanup stale UserDraft attachments"
  task :user_draft_cleanup => :environment do |t|
    puts "** Cleaning up stale UserDraft attachments **"
    cleanup_date = 2.days.ago.utc
    Helpdesk::MultiFileAttachment::AttachmentCleanup.new(:cleanup_date => cleanup_date).cleanup
    puts "** Done **"
  end
end
