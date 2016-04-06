if(!window.Helpdesk) Helpdesk = {};

Helpdesk.MultifileUpload = {	
    
    FILE_LOCATION : /^.*[\\\/]/ ,

    MAX_ATTACHMENT : null,
 
    MAX_SIZE: 15 * 1024 * 1024, // 15 MB : Size in bytes

    VALID_FILE_count: 0 ,

    enabled:true,


    load: function(){
        // jQuery("input[fileList]").each( function () {
        //     console.log("Attachment form " + this);
        //     Helpdesk.MultifileUpload.addEventHandler(this);
        // });
      
          Helpdesk.MultifileUpload.template = jQuery("#multiple-file-list-template").template();
        
    },

    onFileSelected: function(inputEl){ 
        if(jQuery(inputEl).css("display") != "none"){ 
          
                if(this.addMultipleFilesToList(inputEl)) {
               this.cloneInput(inputEl);
           }
              
        }
    },


    duplicateInput: function(inputEl){
        jQuery(inputEl).removeClass('original_input');
        var i2 = jQuery(inputEl).clone();
        i2.attr('id', i2.attr('id') + "_c");
        i2.val("");
        i2.addClass('original_input');
        jQuery(inputEl).before(i2);

        jQuery(inputEl).attr('name',jQuery(inputEl).attr('nameWhenFilled'));
        jQuery(inputEl).hide();
        this.removeEventHandler(inputEl);
        this.addEventHandler(i2); 
        return i2;
    },

    cloneInput: function(inputEl) {
        inputEl.classList.remove('original_input');
        var clonedEl = inputEl.cloneNode(true);
        clonedEl.id += "_c";
        clonedEl.value = "";
        clonedEl.classList.add('original_input');
        inputEl.parentNode.insertBefore(clonedEl,inputEl);

        inputEl.name = inputEl.getAttribute('nameWhenFilled');
        inputEl.style.display = "none";
        this.removeEventHandler(inputEl);
        this.addEventHandler(clonedEl);
        return clonedEl;
    },
	
	changeUploadFile: function(e){ 
		Helpdesk.MultifileUpload.onFileSelected(e); 
	},
	
    addEventHandler: function(inputEl){
        jQuery(inputEl).addClass('original_input');
        jQuery(inputEl).bind('change', function() {
            Helpdesk.MultifileUpload.onFileSelected(inputEl);
        });
    },

    removeEventHandler: function(inputEl){
       jQuery(inputEl).unbind('change');
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

    // For multiple file attachments
    truncateFileName: function(fileName) {
        var MAX_CHARS = 30;
        var ext = fileName.substring(fileName.lastIndexOf(".") + 1, fileName.length).toLowerCase();
        var newFileName = fileName.replace('.' + ext,'');
        if(newFileName.length <= MAX_CHARS) {
            return newFileName;
        }
        newFileName = newFileName.substr(0,MAX_CHARS) + (fileName.length > MAX_CHARS ? '[...]' : '');
        return newFileName + '.' + ext;
    },

    clearErrors: function() {
        var errorElements = document.getElementsByClassName("invalid_attachment");
        while(errorElements.length > 0) {
            errorElements[0].parentNode.removeChild(errorElements[0]);
        }
    },


    addMultipleFilesToList: function(inputEl) {
        this.clearErrors();
        var container = jQuery(inputEl).attr('fileContainer'),
            filesize = 0,
            validFile = true;
        jQuery("#"+container).show();

        var attachedFiles = inputEl.files;
        var filesList = [];
        var totalFileSize = 0;
        var nProcessedFiles = 0;
        for(var i=0, len = attachedFiles.length;i<len;i++) {
            var file = attachedFiles[i];

            validFile = this.exceedsTotalSize(inputEl,file.size);
            if(validFile) {
                this.addtoTotalSize(inputEl,file.size);
                totalFileSize += file.size;
                this.VALID_FILE_count++;
                nProcessedFiles++;
            } else {
                this.deductTotalSize(inputEl,totalFileSize); // revert file size
                this.VALID_FILE_count -= nProcessedFiles;  // revert file count
                break; // We will not check any more attachments since file size exceeded
            }

            var fileSizeKB = (file.size / 1024).toFixed(2);
            var strFileSize = (fileSizeKB >= 1024) ? ((fileSizeKB / 1024).toFixed(2) + ' MB') : (fileSizeKB + ' KB');
            filesList.push({ name:file.name, size: strFileSize, short_name: this.truncateFileName(file.name) });
            
        }
        var target = jQuery("#"+ jQuery(inputEl).attr('fileList'));
        if(validFile) { // we will only show the list of attached files, if all of them passes the size validation
            // Generate Unique IDs for attachments
            var attachmentId = "attachment-" + new Date().getTime();
            target.append(jQuery.tmpl(this.template,{
                inputId: jQuery(inputEl).attr('id'),
                file_valid: true,
                provider: (jQuery(inputEl).data('provider') || "").toLowerCase(),
                files:filesList,
                size_in_bytes: totalFileSize,
                attachment_id: attachmentId
            }));
            // clearing all error statements
            jQuery(".invalid_files").remove();
        } else {
            target.append(jQuery.tmpl(this.template,{
                inputId: jQuery(inputEl).attr('id'),
                file_valid: false,
                provider: (jQuery(inputEl).data('provider') || "").toLowerCase(),
            }));
            // clearing all error statements except current
            var temp=1;
            jQuery.each(jQuery(".invalid_files"),function(key,data){
             if(temp!==1)
                data.remove();
            temp++;

            });

        }
        // increasing count for forward
        var tcount=len+parseInt(jQuery("#"+container + ' .a-count').html());
        jQuery("#"+container + ' .a-count').text(tcount);
        return validFile;
    }, 
    decrementTotalSize: function(fileInput) { 
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

    // for multiple file attachments
    addtoTotalSize: function(inputEl,size) {
        var totalFileSize = this.getTotalSize(inputEl);
        jQuery(inputEl).parents('form').data('totalAttachmentSize',totalFileSize + size);
    },
    deductTotalSize: function(inputEl,size) {
        this.addtoTotalSize(inputEl,-size);
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

    // for multiple file attachments
    exceedsTotalSize: function(inputEl,size) {
        var totalFileSize = this.getTotalSize(inputEl);
        return !((size  + totalFileSize) > this.MAX_SIZE);
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
            var strSize = link.dataset["size"];

            if (window.FileReader)
            {
                
                this.deductTotalSize(strSize);
                // this.decrementTotalSize(fileInput);
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

    // For multiple attachments
    removeAttachments: function(linkEl) {
        try {
            // decreasing count for forward
            var ele=jQuery("#"+jQuery(linkEl).attr('data-attachment'));
            var tcount=ele.children('#files').children("p").length;
            var ocount=jQuery('.a-count:visible').text();
            jQuery('.a-count:visible').text(parseInt(ocount)-parseInt(tcount));
            var inputEl = document.getElementById(linkEl.dataset["input"]);
            var attachmentsEl = document.getElementById(linkEl.dataset["attachment"]);
            var strSize = linkEl.dataset["size"];

            this.deductTotalSize(inputEl,strSize);
            this.VALID_FILE_count--;

            inputEl.parentNode.removeChild(inputEl);
            attachmentsEl.parentNode.removeChild(attachmentsEl);

            return true;
            
        } catch(e) {
            console.log(e);
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
    jQuery("input[fileList]").livequery(function(){ 
    var type=jQuery("#attachment-type").attr('data-multifile-enable');
         if(type=="true")
         {
                var $input_file = jQuery(this)
                Helpdesk.MultifileUpload.load()
                Helpdesk.MultifileUpload.addEventHandler(this)
                jQuery(this.form).off("reset.Multifile")
                jQuery(this.form).on("reset.Multifile", function(){
                    Helpdesk.MultifileUpload.resetAll(this)
                })
         }
    });

});
    
  



