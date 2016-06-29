// This will contain all the code for previewing attachments in tickets

window.App = window.App || {};

(function($){ 

  window.App.TicketAttachmentPreview = {

    supportedFiles: ["png","gif","jpeg","jpg"]

    // This is a simple proxy method helper
    ,p: function(fn){
      return $.proxy(fn,this);
    }

    ,init: function(){
      this.attachListeners();
    }

    ,destroy: function(){
      // Switch off all the event listeners. 
      // Make sure all listeners are on "document"
      $(document).off('.ticket_attachment_preview');
    }

    ,attachListeners: function(){
      var self = this;
    
      // When the user clicks the attachment link, catch it
      // and invoke the popup for the attachment viewer
      $(document).on('click.ticket_attachment_preview',".attach_content a",this.p(this.attachmentClicked));

      // Close the popup when user clicks the close button
      $(document).on('click.ticket_attachment_preview','.av-close',this.p(this.removePopup));
      $(document).on('click.ticket_attachment_preview','.av-media, .av-cannot-preview',this.p(this.removePopupCheck));

      // Switching between attachments
      $(document).on('click.ticket_attachment_preview','.av-next',this.p(this.nextFile));
      $(document).on('click.ticket_attachment_preview','.av-prev',this.p(this.prevFile));
    }

    ,attachKeys: function(){
      // Keyboard functionalities
      $(document).on('keydown.ticket_attachment_preview',function(e){
        switch(e.keyCode){
          case 37: {
            self.prevFile();
            break;
          }
          case 39: {
           self.nextFile();
            break;
          }
          case 27: {
            self.removePopup();
          }
        }
      })
    }

    ,removeKeys: function(){
      $(document).off('keydown.ticket_attachment_preview');
    }

    ,attachmentClicked: function(event){
      this.getAllAttachments(event);

      // Show the current file popup only for supported files.
      if(this.supportedFiles.indexOf(this.attachments[this.currentPosition].filetype)>-1){
        this.showCurrentFile();
      }
    }

    ,showCurrentFile: function(){
      // Cleanup if necessary
      this.removePopup();

      var currentFile = this.attachments[this.currentPosition];

      this.showPopup({
        filelink: currentFile.filelink,
        filename: currentFile.filename,
        currentPos: this.currentPosition,
        length: this.attachments.length,
        filetype: currentFile.filetype
      });

      // Cancel event propogation
      event.preventDefault();
      return false;
    }

    ,nextFile: function(){
      if(this.currentPosition==this.attachments.length-1) return;
      this.currentPosition++;
      this.showCurrentFile();
    }

    ,prevFile: function(){
      if(this.currentPosition==0) return;
      this.currentPosition--;
      this.showCurrentFile();
    }

    ,getAllAttachments: function(event){
      this.attachments = [];
      self = this;
      
      // Iterate through all the attachments in the 
      // conversation and create the attachment objects array.
      var attachmentElements = $(event.target).parents(".attachment_list").find('.attachment');
      this.currentPosition = $(event.target).parents(".attachment").index();
      attachmentElements.each(function(i,el){
        var $el = $(el);
        self.attachments.push({
          filename: $el.find(".attach_content a").data("original-title") || $el.find(".attach_content a").attr('title')
          ,filelink: $el.find(".attach_content a").attr("href")
          ,filetype: $el.find(".attachment-type .file-type").text()
        })
      })
    }

    ,showPopup: function(viewerData){
      // Create the popup
      var template = "tickets/templates/attachment-viewer";
      var popup = JST["tickets/templates/attachment-viewer"](viewerData);
      $('body').append(popup);

      this.attachKeys();
    }

    ,removePopupCheck: function(e){
      if($(e.target).hasClass("av-media") || $(e.target).hasClass("av-cannot-preview") )
        this.removePopup();
    }

    ,removePopup: function(){
      this.removeKeys();
      $('.attachments-viewer').remove();
    }
  }
})(jQuery);