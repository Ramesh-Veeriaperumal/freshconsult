function ctiEventListener(ev) {
  var data = ev.data
  if(ev.origin != screenPop.iframeHost){
    return;
  }
  if(data.action == "show_softphone"){
    var $target  = jQuery('#cti_softphone_icon');
    jQuery('.cti-widget').data('popupbox').toggleTarget($target, false);
  } else if(data.action == "open_ticket") {
    var ticket_path = "/helpdesk/tickets/" + data.value;
    jQuery.pjax({url: ticket_path, container: '#body-container', timeout: -1});
  } else if (data.action == "open_contact") {
    var contact_path = "/contacts/" + data.value;
    jQuery.pjax({url: contact_path, container: '#body-container', timeout: -1});
  }
}
jQuery(document).on('ready', function() {
  window.addEventListener ? addEventListener("message", ctiEventListener, false) : attachEvent("onmessage", ctiEventListener);
});
