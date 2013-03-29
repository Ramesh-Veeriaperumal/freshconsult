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
            this.addFileToList(input);
            this.duplicateInput(input);
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
        var container = jQuery(oldInput).attr('fileContainer');
        jQuery("#"+container).show();
		
        var target = jQuery("#"+jQuery(oldInput).attr('fileList'));
        target.append(jQuery.tmpl(this.template, {
                name: jQuery(oldInput).val().replace(/^.*[\\\/]/, ''),
                inputId: jQuery(oldInput).attr('id')
            }));
        jQuery("#"+container + ' label i').text(target.children(':visible').length);
    },
    remove: function(link){
		try{
            var fileInput = jQuery('#'+jQuery(link).attr('inputId'));
            var target = jQuery("#"+jQuery(fileInput).attr('fileList'));
            var container = jQuery(fileInput).attr('fileContainer');

			jQuery('#'+jQuery(link).attr('inputId')).remove();
            jQuery(link).parents("div:first").remove();

            jQuery("#"+container + ' label i').text(target.children(':visible').length);
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
        if (inputs.length >= 1) {
            console.log(jQuery("#"+inputs.first().attr('fileList')).children());
            jQuery("#"+inputs.first().attr('fileList')).children().not('[rel=original_attachment]').remove();
            jQuery("#"+inputs.first().attr('fileList')).children().show();
            inputs.prop('disabled', false);
            jQuery("#"+inputs.first().attr('fileContainer')+ ' label i').text(jQuery("#"+inputs.first().attr('fileList')).children().length);
            inputs.not(".original_input").remove();
        }

    }
};

jQuery("document").ready(function(){
    // setTimeout(function() {
    //     Helpdesk.Multifile.load();
    // },500);
    
    jQuery("input[fileList]").livequery(function(){ 
        $input_file = jQuery(this)
        Helpdesk.Multifile.load()
        Helpdesk.Multifile.addEventHandler(this)
        jQuery(this.form).off("reset.Multifile")
        jQuery(this.form).on("reset.Multifile", function(){
            Helpdesk.Multifile.resetAll(this)
        })
    });
});

