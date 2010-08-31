
Helpdesk.monitorTakeItButtons = function(){
    Event.observe('pages', 'click', function(event){
        if(Element.hasClassName(event.target, 'accept-button')){
            var form = $('accept-form');
            form.action = Element.readAttribute(event.target, 'action'); 
            form.submit();
            event.preventDefault();
        }
    });
}
