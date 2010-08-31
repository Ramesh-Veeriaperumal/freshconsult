if(!window.Helpdesk) Helpdesk = {};

Object.extend(Helpdesk, {
    monitorTicketSearch: function(){

        Event.observe('search-all', 'click', function(event){
            var f = $('search-form');
            f.action = Element.readAttribute(f, 'searchallaction'); 
            f.submit();
            
        });

        Event.observe('ticket-search-field', 'change', function(event){
            activateTicketSearchInput(event.target.value);
        });

        activateTicketSearchInput($('ticket-search-field').value, true);

        function activateTicketSearchInput(id, preserveValue){
            $$('.search-field').each(function(f){
                Element.hide(f);
                Form.Element.disable(f);
                f.name = "disbled";
            });

            var field = $('search-' + id) 

            Element.update('search-value-label', field ? 'Is' : 'Is Like');
            
            field = field || $('search-default');

            if(!preserveValue)
                field.value = "";

            field.name = "v";

            Element.show(field);
            Form.Element.enable(field);
            Form.Element.activate(field);
        }

    }
});

document.observe("dom:loaded", Helpdesk.monitorTicketSearch);
