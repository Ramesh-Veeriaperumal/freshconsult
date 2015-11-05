if(!window.Helpdesk) Helpdesk = {};

Helpdesk.Multifile = {	
    
    FILE_LOCATION : /^.*[\\\/]/ ,

    MAX_ATTACHMENT : null,
 
    MAX_SIZE: 15 ,

    VALID_FILE_count: 0 ,

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
            filesize = 0,
            validFile = true,
            filereader = !!window.FileReader;

        jQuery("#"+container).show();

        if (filereader)
        {
    		filesize = this.findFileSize(oldInput);

            validFile = this.validateTotalSize(oldInput);
            if(validFile){
                this.incrementTotalSize(oldInput,filesize);
                this.VALID_FILE_count = this.VALID_FILE_count + 1;
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
                name: jQuery(oldInput).data('filename') || jQuery(oldInput).val().replace(this.FILE_LOCATION, ''),
                inputId: jQuery(oldInput).attr('id'),
                size: filesize,
                file_valid: validFile,
                provider: (jQuery(oldInput).data('provider') || "").toLowerCase()
            }));
        jQuery("#"+container + ' .a-count').text(target.children(':visible').length);
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

        if (jQuery(fileInput).attr('max_attachment') && jQuery(fileInput).attr('max_size') )
        {
            this.MAX_ATTACHMENT = jQuery(fileInput).attr('max_attachment');
            this.MAX_SIZE = jQuery(fileInput).attr('max_size'); 
            return !((filesize + totalfilesize) > this.MAX_SIZE) && this.checkFileType(fileInput) && this.VALID_FILE_count < this.MAX_ATTACHMENT;

        }
        else
        {
            return !((filesize + totalfilesize) > this.MAX_SIZE);
        }
    },

    checkFileType: function(fileInput){
 
        var supported_types = ["jpg", "jpeg", "gif", "png", "bmp", "tif"]
        var type = jQuery(fileInput).prop("files")[0].name.split('.').pop().toLowerCase();
        return supported_types.indexOf(type) > -1 ;
    },

    findFileSize: function(oldInput){
        if(jQuery(oldInput)[0].files && jQuery(oldInput).attr('type') === 'file'){
            return jQuery(oldInput)[0].files[0].size / (1024 * 1024);    
        }
        else{
            return 0;
        }
    },

    remove: function(link){
		try{
            var fileInput = jQuery('#'+jQuery(link).attr('inputId'));
            if (window.FileReader)
            {
                this.decrementTotalSize(fileInput);
                this.VALID_FILE_count = this.VALID_FILE_count - 1;
            }
            var target = jQuery("#"+jQuery(fileInput).attr('fileList'));
            var container = jQuery(fileInput).attr('fileContainer');
			jQuery('#'+jQuery(link).attr('inputId')).remove();
            jQuery(link).parents("div:first, .attachment.list_element").remove();
            jQuery("#"+container + ' .a-count').text(target.children(':visible').length);
            return true;
		}catch(e){
			alert(e);
		}
    },    

    updateCount: function(item) {
        var target = jQuery("#"+jQuery(item).attr('fileList'));
        var container = jQuery(item).attr('fileContainer');
        jQuery("#"+container + ' .a-count').text(target.children(':visible').length);
    },    

    resetAll: function(form) {

        var inputs = jQuery(form).find("input[fileList]");
        jQuery(form).data('totalAttachmentSize',0);
        if (inputs.length >= 1) {
            jQuery("#"+inputs.first().attr('fileList')).children().not('[rel=original_attachment]').remove();
            jQuery("#"+inputs.first().attr('fileList')).children().show();
            inputs.prop('disabled', false);
            jQuery("#"+inputs.first().attr('fileContainer')+ ' .a-count').text(jQuery("#"+inputs.first().attr('fileList')).children().length);
            inputs.not(".original_input").remove();
        }

    }
};

jQuery("document").ready(function(){
    // setTimeout(function() {
    //     Helpdesk.Multifile.load();
    // },500);
    
    jQuery("input[fileList]").livequery(function(){ 
        var $input_file = jQuery(this)
        Helpdesk.Multifile.load()
        Helpdesk.Multifile.addEventHandler(this)
        jQuery(this.form).off("reset.Multifile")
        jQuery(this.form).on("reset.Multifile", function(){
            Helpdesk.Multifile.resetAll(this)
        })
    });
});

