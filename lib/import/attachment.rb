require 'timeout'

class Import::Attachment
  include Import::Zen::Redis
  attr_accessor :id , :attach_url , :model, :account, :username, :password
  def initialize(params={})
    self.id = params[:item_id]
    self.attach_url = params[:attachment_url]
    self.model = params[:model].to_sym
    self.account = Account.current
    self.username = params[:username]
    self.password = params[:password]
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
        file = Timeout.timeout(60) { RemoteFile.new(attach_url, username, password) }
        attachment = @item.attachments.build(:content => file , :description => "", :account_id => @item.account_id)
        
        if attachment.save!
          @item.update_es_index
          @item.send(:update_searchv2)
        end
      rescue Timeout::Error => ex
        raise Timeout::Error, "Timeout on attachment import"
      rescue => e
        puts "#{e.message}\n#{e.backtrace.join("\n")}"
        puts "Attachment exceed the limit!"
        NewRelic::Agent.notice_error(e)
      ensure
        if file
          file.unlink_open_uri if file.open_uri_path
          file.close
          file.unlink
        end
        increment_key 'attachments_completed'
      end
    end
  end
end