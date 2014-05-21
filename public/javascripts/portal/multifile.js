// !IMPORTANT
// Multi file selector for portal & feedbackwidget

if(!window.Helpdesk) Helpdesk = {};
Helpdesk.Multifile = {	
    load: function(){
        // jQuery("input[fileList]").each( function () {
        //     console.log("Attachment form " + this);
        //     Helpdesk.Multifile.addEventHandler(this);
        // });
        Helpdesk.Multifile.template = jQuery("#file-list-template").template();
    },

    onFileSelected: function(input){ 
        if(jQuery(input).css("display") != "none"){           
           this.duplicateInput(input);
           if (!this.addFileToList(input)) {
                jQuery(input).remove();
           }
        }
    },

    duplicateInput: function(input){
        jQuery(input).removeClass('original_input');
        var i2 = jQuery(input).clone();
        i2.attr('id', i2.attr('id') + "_c");
        i2.val("");
        i2.addClass('original_input');
        jQuery(input).before(i2);

        jQuery(input).attr('name',jQuery(input).attr('nameWhenFilled'));
        jQuery(input).hide();

        jQuery("#"+jQuery(input).data("attachId")+"_proxy_link").data("fileId", i2.attr("id"));
        this.removeEventHandler(input);
        this.addEventHandler(i2); 
        return i2;
    },
	
	changeUploadFile: function(e){ 
		Helpdesk.Multifile.onFileSelected(e); 
	},
	
    addEventHandler: function(input){
        jQuery(input).addClass('original_input');
        jQuery(input).bind('change', function() {
            Helpdesk.Multifile.onFileSelected(input);
        });
    },

    removeEventHandler: function(input){
       jQuery(input).unbind('change');
    },

        addFileToList: function(oldInput){
        var container = jQuery(oldInput).attr('fileContainer'),
            filesize = '0.00 KB ',
            validFile = true,
            filereader = !!window.FileReader;

        jQuery("#"+container).show();

        if (filereader)
        {
            filesize = this.findFileSize(oldInput);

            validFile = this.validateTotalSize(oldInput);
            if(validFile){
                this.incrementTotalSize(oldInput,filesize);
            }
            if (filesize < 1)
            {
                filesize *=1024;
                filesize = filesize.toFixed(2) + ' KB '; 
            }
            else
            {
                filesize = filesize.toFixed(2) + ' MB ';
            }
        }
        var target = jQuery("#"+jQuery(oldInput).attr('fileList'));
        target.append(jQuery.tmpl(this.template, {
                name: jQuery(oldInput).val().replace(/^.*[\\\/]/, ''),
                inputId: jQuery(oldInput).attr('id'),
                size: filesize,
                file_valid: validFile
            }));
        jQuery("#"+container + ' label i').text(target.children(':visible').length);

        return validFile;
    },

    decrementTotalSize: function(fileInput)
    {
        var filesize = this.findFileSize(fileInput);
        this.incrementTotalSize(fileInput, -filesize);
    },

    getTotalSize: function(fileInput){
        return jQuery(fileInput).parents('form').data('totalAttachmentSize') || 0;
    },

    incrementTotalSize: function(fileInput, addition){
        var totalfilesize = this.getTotalSize(fileInput);
        jQuery(fileInput).parents('form').data('totalAttachmentSize', totalfilesize + addition);
    },

    validateTotalSize: function(fileInput){
        var totalfilesize = this.getTotalSize(fileInput);
        var filesize = this.findFileSize(fileInput);
        return !((filesize + totalfilesize) > 15);
    },

    findFileSize: function(oldInput){
      if(jQuery(oldInput)[0].files){
        return jQuery(oldInput)[0].files[0].size / (1024 * 1024);    
      }
      else{
        return 0;
      }
    },

    remove: function(link){
        try{
            var fileInput = jQuery('#'+jQuery(link).attr('inputId'));
            if (!!window.FileReader)
            {
                this.decrementTotalSize(fileInput);
            }

            var target = jQuery("#"+jQuery(fileInput).attr('fileList'));
            var container = jQuery(fileInput).attr('fileContainer');

            jQuery('#'+jQuery(link).attr('inputId')).remove();
            jQuery(link).parents("div:first").remove();

            jQuery("#"+container + ' label i').text(target.children(':visible').length);
            return true;
        }catch(e){
            alert(e);
        }
    },    

    updateCount: function(item) {
        var target = jQuery("#"+jQuery(item).attr('fileList'));
        var container = jQuery(item).attr('fileContainer');
        jQuery("#"+container + ' label i').text(target.children(':visible').length);
    },

    resetAll: function(form) {
        var inputs = jQuery(form).find("input[fileList]");
        jQuery(form).data('totalAttachmentSize',0);
        if (inputs.length >= 1) {
            jQuery("#"+inputs.first().attr('fileList')).children().not('[rel=original_attachment]').remove();
            jQuery("#"+inputs.first().attr('fileList')).children().show();
            inputs.prop('disabled', false);
            jQuery("#"+inputs.first().attr('fileContainer')+ ' label i').text(jQuery("#"+inputs.first().attr('fileList')).children().length);
            inputs.not(".original_input").remove();
        }
    },
    clickProxy: function(source){
        jQuery("#" + jQuery(source).data("fileId")).click();
    }
};

!function( $ ) {

    $(function () {

        "use strict"
        
        $("[rel=attach-file]").on("click", function(ev){
            var $this = $(this) 
            // console.log($this.data("attachContainer"))

        })

        $("input[fileList]").livequery(function(){ 
            var $input_file = $(this)
            Helpdesk.Multifile.load()
            Helpdesk.Multifile.addEventHandler(this)
            $(this.form).off("reset.Multifile")
            $(this.form).on("reset.Multifile", function(){
                Helpdesk.Multifile.resetAll(this)
            })
        })

    })

}(window.jQuery);