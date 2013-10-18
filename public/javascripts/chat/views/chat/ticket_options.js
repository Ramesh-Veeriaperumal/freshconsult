define([
  'text!templates/chat/close/ticket_options.html',
  'views/chat/create_ticket',
  'views/chat/ticket_search'
], function(optionTemplate,createTicket,searchTicket){
  var $ = jQuery;
  var TicketView = Backbone.View.extend({
        render:function(chat) {
            var that=this;
            $('body').append(_.template(optionTemplate,{visitor_name:chat.visitor.name}));
            that.listen(chat);
        },
        listen:function(chat) {
            $('#new_tkt').on('click', function(){
                $('#new_tkt').text(i18n.creating_ticket);
                $('#new_tkt, #do_nothing, #confirm_tkt, #existing_tkt_link, #return_select_tkt')
                        .addClass('disabled');
                createTicket.create(chat);
            });

            $('#existing_tkt_link,#return_select_tkt').on('click', function(){  
                $('#ticket_options').hide();
                if( $('#ticket_search_view').length){
                  $('#ticket_search_view').show();
                }
                else{
                 searchTicket.render(chat);
                }
            });

            $('#do_nothing').on('click',function(){
                $('#ticket_search_view').remove();
                $('#chat_ticket_options').remove();
                createTicket.closeChatWindow(chat);
            });

            $('#confirm_tkt').on('click', function(){
                $('#confirm_tkt').text(i18n.adding_note);
                $('#new_tkt, #do_nothing, #confirm_tkt')
                      .addClass('disabled');
                      $("#return_select_tkt").remove();
                chat.existing_tkt_id = searchTicket.selected_ticket();
                createTicket.create(chat);
            });
        }
  });
        return  (new TicketView());
});
