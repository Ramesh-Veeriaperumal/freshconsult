if(!window.Helpdesk) Helpdesk = {};
Helpdesk.Multifile = {	
    load: function(){
        jQuery("input[fileList]").each( function () {
            Helpdesk.Multifile.addEventHandler(this);
        });
        Helpdesk.Multifile.template = jQuery("#file-list-template").template();
    },

    onFileSelected: function(input){ 
        if(jQuery(input).css("display") != "none"){ 
            this.addFileToList(input);
            this.duplicateInput(input);
        }
    },

    duplicateInput: function(input){
        i2 = jQuery(input).clone();
        i2.attr('id', i2.attr('id') + "_c");
        i2.val("");
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
        target.prepend(jQuery.tmpl(this.template, {
                name: jQuery(oldInput).val(),
                inputId: jQuery(oldInput).attr('id')
            }));
    },
    remove: function(link){
		try{
			jQuery('#'+jQuery(link).attr('inputId')).remove();
            jQuery(link).parents("div:first").remove();
		}catch(e){
			alert(e);
		}
    },
    resetAll: function() {
        jQuery("input[fileList]").each( function () {
            jQuery(this).val("");
            var target = jQuery("#"+jQuery(this).attr('fileList'));
            target.html("");
        });
    }
};

jQuery("document").ready(function(){
     setTimeout(function() {
        Helpdesk.Multifile.load();
    },500);
});

