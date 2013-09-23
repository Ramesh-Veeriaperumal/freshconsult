function createDialog(userId){
 console.log(" this is from create dialog...")
}

$(document).ready(function(){
          var box = null;
          var counter = 0;
          var idList = new Array();
          $("#toggle").click(function(event, ui) {
              if(box) {
                  box.chatbox("option", "boxManager").toggleBox();
              }
              else {
                  box = $("#chat_div").chatbox({id:"chat_div", 
                                                user:{key : "value"},
                                                title : "test chat",
                                                messageSent : function(id, user, msg) {
                                                    $("#log").append(id + " said: " + msg + "<br/>");
                                                    $("#chat_div").chatbox("option", "boxManager").addMsg(id, msg);
                                                }}).draggable({ addClasses: true,appendTo: "body" });
              }
          });

          $("#add_chat").click(function(event, ui) {
					counter ++;
					var id = "box" + counter;
					idList.push(id);
					dialogManager.addBox(id,
					{dest:"dest" + counter, // not used in demo
					title:"box" + counter,
					first_name:"First" + counter,
					last_name:"Last" + counter
					//you can add your own options too
					});
					event.preventDefault();
				});
          
				  $('#create').each(function() {  
				    $.data(this, 'dialog',
				      $(this).next('.chat_dialog').dialog({
				        autoOpen: false,  
				        modal: false,  
				        title: 'Info',  
				        width: 600,  
				        height: 400,  
				        position: [200,50],  
				        draggable: true 
				      })
				    );  
				  }).click(function() {  
				      $.data(this, 'dialog').dialog('open');  
				      return false;  
				  });
});