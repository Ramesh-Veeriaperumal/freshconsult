if(!window.Helpdesk) Helpdesk = {};

Helpdesk.Multifile = {

    load: function(){
        $$("input[fileList]").each(Helpdesk.Multifile.addEventHandler);

        Helpdesk.Multifile.template = new Template($('file-list-template').value);
    },

    onFileSelected: function(input){
        this.addFileToList(input);
        this.duplicateInput(input);
    },

    duplicateInput: function(input){
        i2 = input.cloneNode(true);
        i2.id += "_c";
        i2.value = "";
        input.insert({before: i2})

        input.name = input.readAttribute('nameWhenFilled');
        input.hide();
        this.removeEventHandler(input);
        this.addEventHandler(i2);

        return i2
    },

    addEventHandler: function(input){
        input.observe('change', function(e){ Helpdesk.Multifile.onFileSelected(e.target)} );
    },

    removeEventHandler: function(input){
        input.stopObserving('change');
    },

    addFileToList: function(oldInput){
		var container = $(oldInput.readAttribute('fileContainer'));
		container.show();
		
		
        var target = $(oldInput.readAttribute('fileList'));
        target.insert({
            top: this.template.evaluate({
                name: oldInput.value,
                inputId: oldInput.id
            })
        });

        var description = target.down('input')
        description.activate();

        // Pressing enter inside description box should NOT
        // submit the form.
        description.observe('keypress', function(e){

            // On ESC, return focus to the main editor
            if(e.keyCode == 27){
                $(oldInput.readAttribute('sendFocusTo')).activate();
            }

            // On ENTER or TAB, cycle through descriptions
            if(e.keyCode == 13 || e.keyCode == 9){
                //(e.target.up('tr').next('tr').down('input[type=text]') || $(oldInput.readAttribute('sendFocusTo'))).activate();
                var n = e.target.up('div');
                var n = n.next('div');

                (n ? n.down('input') : $(oldInput.readAttribute('sendFocusTo'))).activate();

                e.preventDefault();
            }


        });

    },

    remove: function(link){
        $(link.readAttribute('inputId')).remove();
        link.up('div').remove();
    }
    




}

document.observe("dom:loaded", Helpdesk.Multifile.load);
