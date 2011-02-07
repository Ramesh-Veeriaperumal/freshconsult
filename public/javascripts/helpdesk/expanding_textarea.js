if(!window.Helpdesk) Helpdesk = {};

Object.extend(Helpdesk, {
    expandTextArea: function(textarea){
        if(!textarea.expanded){
            textarea.expanded = true;
            Element.setStyle(textarea, {height: '150px', overflow: "auto" });
        }
    },
    monitorTextAreas: function(){
        $$('textarea.expando').each(function(t){
            Event.observe(t, 'focus', function(){
                Helpdesk.expandTextArea(this);
            });            
        });
    }
});

document.observe("dom:loaded", Helpdesk.monitorTextAreas);
