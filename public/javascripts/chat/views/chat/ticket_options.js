define([
  'text!templates/chat/close/ticket_options.html',
  'views/chat/create_ticket',
  'views/chat/ticket_search'
], function(optionTemplate,createTicket,searchTicket){
  var $ = jQuery;
  var TicketView = Backbone.View.extend({
        render:function(chat) {
            var that=this;
            $('body').append(_.template(optionTemplate));
            that.listen(chat);
        },
        listen:function(chat) {
            $('#new_tkt').on('click', function(){
                $('#chat_ticket_options').remove();
                $('#ticket_search_view').remove();
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
            });

            $('#confirm_tkt').on('click', function(){
                $('#chat_ticket_options').remove();
                $('#ticket_search_view').remove();
                chat.existing_tkt_id = searchTicket.selected_ticket();
                createTicket.create(chat);
            });
        }
  });
        return  (new TicketView());
});
