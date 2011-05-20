

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
  @item.attachments.create(:content =>  RemoteFile.new(attach_url), :description => "", :account_id => @item.account_id) unless @item.blank?
  end   
  
end