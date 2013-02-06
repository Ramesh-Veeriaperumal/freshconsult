

class Import::Attachment
  attr_accessor :id , :attach_url , :model, :account
  def initialize(id ,attach_url , model, account_id)
    self.id = id
    self.attach_url = attach_url
    self.model = model
    self.account = Account.find(account_id)
  end
  
  def perform
    @item = nil
    case model    
      when :ticket
        @item = account.tickets.find(id)
      when :note
        @item = account.notes.find(id)
      when :post
        @item = account.posts.find(id)
      when :article
        @item = account.solution_articles.find(id)
    end
    if @item
     begin
        file = RemoteFile.new(attach_url)
        attachment = @item.attachments.build(:content => file , :description => "", :account_id => @item.account_id)
        attachment.save!
      rescue
        puts "Attachmnet exceed the limit!"
        NewRelic::Agent.notice_error(e)
      ensure
        if file
          file.unlink_open_uri if file.open_uri_path
          file.close
          file.unlink
        end
      end
    end
  end
end