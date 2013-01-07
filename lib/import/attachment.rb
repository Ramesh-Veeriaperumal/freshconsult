

class Import::Attachment
  attr_accessor :id , :attach_url , :model
  def initialize(id ,attach_url , model)
    self.id = id
    self.attach_url = attach_url
    self.model = model
  end
  
  def perform
    @item = nil
    case model    
      when :ticket
        @item = Helpdesk::Ticket.find(id)
      when :note
        @item = Helpdesk::Note.find(id)
    end
    begin
      if @item
        attachment = @item.attachments.build(:content =>  RemoteFile.new(attach_url), :description => "", :account_id => @item.account_id)
        attachment.save!
      end
    rescue
      puts "Attachmnet exceed the limit!"
      NewRelic::Agent.notice_error(e)
      return
    end
  end
  
end