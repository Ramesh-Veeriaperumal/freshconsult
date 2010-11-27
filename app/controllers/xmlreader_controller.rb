class XmlreaderController < ApplicationController
  def xmlreader
  end

  def importxml
    
      puts "inside import xml "
    
    require 'rexml/document'
    
    require 'rexml/xpath'
    
    file=params[:dump][:file]
    
    doc=REXML::Document.new(file.read)  

    # terating ticket elements
    REXML::XPath.each(doc,'//ticket') do |req| 
        
        sub = nil 
        desc = nil
        
        #filtering each fields
        
        req.elements.each("subject") do |subject|
          
          puts "subject value is"       
        
          sub = subject.text
         
        end
        
        req.elements.each("description") do |description|    
       
          desc = description.text
         
        end    
       
       puts sub
       
       puts desc
       
       # saving the data to ticket
       
       request = Helpdesk::Ticket.new(:subject => sub, :description =>desc, :account_id => '1')      
      
       request.save
        
       end
  end

end
