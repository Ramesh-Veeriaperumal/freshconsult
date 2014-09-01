if(!window.Helpdesk) Helpdesk = {};

Helpdesk.DDReorder = function(o){
    this.o = o;

    this.sortable = Sortable.create(o.container, {
        ghosting: false, 
        constraint: 'vertical', 
        overlap: 'vertical', 
        scroll: window 
    });
}


Helpdesk.DDReorder.prototype = {

    start: function(){
        $('main-panel-toolbar-1').hide();
        $('main-panel-toolbar-2').show();
    },

    submit: function(){
        var form = $(this.o.form);
        form.down('#' + (this.o.fieldName || 'order')).value = Sortable.sequence(this.o.container);
        form.submit();
    },

    cancel: function(){
        $('main-panel-toolbar-1').show();
        $('main-panel-toolbar-2').hide();
        if(this.o.onCancel) this.o.onCancel();
    }
    

}

