/*global
 Class, FreshdeskSocket, screenPop
 */
var CtiFeature = function() {
  this.freshSocket = new FreshdeskSocket({
    name: "cti"
  }).socket;

  this.freshSocket.on('incoming_call', function(data) {
    data = JSON.parse(data);
    screenPop.resetValues();
    screenPop.requester_id = data.requester_id;
    screenPop.ticket_id = data.ticket_id;
    screenPop.call_id = data.id;
    screenPop.new_ticket = data.new_ticket;
    screenPop.loadContext();
  });

  this.freshSocket.on('clear_pop', function(data) {
    screenPop.resetForm();
  });
}

jQuery(document).ready(function(){
  ctiFeature = new CtiFeature();
});

