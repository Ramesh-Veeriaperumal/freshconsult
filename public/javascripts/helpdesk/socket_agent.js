window.ticket_view = true;

var current_agents = {};
var current_agents_replying = {};

var ticket_status = {
  connected : false,
  ticket_draft: false
};

function update_notification_ui_ticket (viewing,replying) {
    viewing = jQuery(viewing).not(replying).get();
    jQuery("#agents_viewing").toggleClass("active", (viewing.length != 0)).effect("highlight", {
        color: "#fffff3"
    }, 400);
    jQuery("#agents_viewing .flip-back").html(viewing.length);
    jQuery("#agents_replying").toggleClass("active", (replying.length != 0)).effect("highlight", {
        color: "#fffff3"
    }, 400);
    jQuery("#agents_replying .flip-back").html(replying.length);
};

function AddAgents(params){
  // console.log('going into AddAgents ');
  for(var i=0; i< params.length; i++){
    var socket_id = params[i]["client_socket"] ? params[i]["client_socket"] : params[i]["socket_id"];
    if(params[i]["reply"] && params[i]["reply"]!= undefined){
      // console.log('The value of the replying is ');
      if(!current_agents_replying[params[i]["user_id"]]){
          current_agents_replying[params[i]["user_id"]] = {};
      }
      current_agents_replying[params[i]["user_id"]][socket_id] = {
        "user_name": params[i]["user_name"]
      }    
    }
    else{
      // console.log('not replying')
      if(!current_agents[params[i]["user_id"]]){
          current_agents[params[i]["user_id"]] = {};
      }
      current_agents[params[i]["user_id"]][socket_id] = {
        "user_name": params[i]["user_name"]
      }
    }
  }
  update_notification_ui_ticket(Object.keys(current_agents), Object.keys(current_agents_replying));
};

function RemoveAgents(params){
  // console.log('Going to remove the agent ',params);
  if(params["reply"]){
    if(current_agents_replying[params["user_id"]]){
      if(current_agents_replying[params["user_id"]][params["socket_id"]]){
        delete current_agents_replying[params["user_id"]][params["socket_id"]]
      }
    }
    if(Object.keys(current_agents_replying[params["user_id"]]).length == 0){
        delete current_agents_replying[params["user_id"]]
    }
    if(!current_agents[params["user_id"]]){
      current_agents[params["user_id"]] = {}
    }
    current_agents[params["user_id"]][params["socket_id"]] = {
      "user_name" : params["user_name"]
    }
  }
  else{
    if(current_agents[params["user_id"]]){
      if(current_agents[params["user_id"]][params["socket_id"]]){
        delete current_agents[params["user_id"]][params["socket_id"]]
      }
    }
    if(Object.keys(current_agents[params["user_id"]]).length == 0){
        delete current_agents[params["user_id"]]
    }    
  }
  update_notification_ui_ticket(Object.keys(current_agents), Object.keys(current_agents_replying));
};

function RemoveAgentsSocket(params){
  for(var key in current_agents_replying){
    for(var id in current_agents_replying[key]){
      if(params["socket_id"] == id){
        delete current_agents_replying[key][id];
      }
    }
    if(Object.keys(current_agents_replying[key]).length == 0){
        delete current_agents_replying[key]
    }   
  }
  for(var key in current_agents){
    for(var id in current_agents[key]){
      if(params["socket_id"] == id){
        delete current_agents[key][id];
      }
    }
    if(Object.keys(current_agents[key]).length == 0){
        delete current_agents[key]
    }   
  }
  update_notification_ui_ticket(Object.keys(current_agents), Object.keys(current_agents_replying));
};

var setEvents = function (hashed_params,current_username,current_userid) {   
    // console.log('setting events');      
    
    jQuery(function(){  
      jQuery('#agent_collision_placeholder').append(jQuery('#agent_collision_show').detach());
      jQuery('[data-note-type]').on("click.agent_collsion",function (e) {
        // console.log('clicking reply note');
        if(hashed_params && ticket_status.connected){
          ticket_status.draft = true;
          window.node_socket.emit('agent_collision_reply',{
            "user_name" : current_username,
            "user_id" : current_userid
          });
        }
      });

      jQuery('.reply_agent_collision').on("click.agent_collsion",function () {
        // console.log('clicking reply exit');
        if(hashed_params){
          ticket_status.draft = false;
          window.node_socket.emit('agent_collision_reply_stop',{
            "user_name" : current_username,
            "user_id" : current_userid
          });
        }
      });
      jQuery("[rel=notice-popover]").popover({
          html: true,
          trigger: "manual",
          content: function () {
              container = "";
              if (this.id != "notification") {
                  agents = current_agents;
                  if(jQuery(this).data("object") == "viewing"){
                    // console.log('This is in current_agents viewing ',current_agents);
                    viewing = Object.keys(current_agents);
                    viewing = jQuery(viewing).not(Object.keys(current_agents_replying)).get();
                    // console.log('The value of viewing is ',viewing);
                    for(var i=0;i<viewing.length;i++){
                      j = Object.keys(current_agents[viewing[i]])[0];
                      if(current_agents[viewing[i]][j]){
                        container += "<div>" + current_agents[viewing[i]][j]["user_name"] + "</div>";
                      } 
                    }
                  }
                  else if(jQuery(this).data("object") == "replying"){
                    // console.log('The value of replying is ',current_agents_replying);
                    for(var key in current_agents_replying){
                      i = Object.keys(current_agents_replying[key])[0];
                      if(current_agents_replying[key][i]){
                        container += "<div>" + current_agents_replying[key][i]["user_name"] + "</div>";
                      } 
                    }
                  }
              } else {
                  container += "Click to refresh ticket...";
              }
              // console.log('The value of the container is ',container);
              return container;
          },
          template: '<div class="arrow notice-arrow"></div><div class="ticket-notice-popover"><div class="title"></div><div class="content"><p></p></div></div>'
      }).live({
          mouseenter: function () {
              if (jQuery(this).hasClass("active")){
                  jQuery(this).popover('show');
                  // console.log('The value of the popover is show');
              }
          },
          mouseleave: function () {
              jQuery(this).popover('hide');
          }
      });
    });

};


window.agentcollision = function(server,hashed_params,current_username,current_userid,draft)
{
  setEvents(hashed_params,current_username,current_userid,draft);
  ticket_status.draft = draft;
  // console.log('The value of server is ',server);
  var node_socket = agentio.connect(server,{'force new connection':true});
  window.node_socket = node_socket;
  node_socket.on('connect', function(){
    // console.log('I have ticket_status.connected');
  });
  node_socket.on('agent_collision',function(data){
    if(data.action === 'connect'){
      hashed_params['previous_clients'] =[];
      node_socket.emit('agent_collision_connect',hashed_params);
    }
  });
  node_socket.on('message', function(params){
      // console.log('have message here',params);
  });

  node_socket.on('connection_complete',function(){
      // console.log('I have connection complete '+draft);
      ticket_status.connected = true;
      if(ticket_status.draft){
        node_socket.emit('agent_collision_reply',{
          "user_name" : current_username,
          "user_id" : current_userid
        });
      }
  });

  node_socket.on('view_event', function(params){
    // console.log('have view here',params);
    // console.log('The current socket_id is '+node_socket.id);
    if(params["user_id"] != current_userid && params['user_name'] != current_username){
     AddAgents([params]);
    }
  });

  node_socket.on('previous_clients',function(params){
      // console.log('The value of the other clients is',params);
      AddAgents(params["concurrent_users"]);
      // console.log('The value of the current agent si s',current_agents);
  });

  node_socket.on('current_agent_leaving',function(params){
    // console.log('We have a current agents leaving');
    RemoveAgentsSocket(params);
  })

  node_socket.on('ticket_reply_event', function(params){
    // console.log('going to reply event ',params);
    if(params["user_id"] != current_userid && params['user_name'] != current_username){
      params["reply"] = true;
      AddAgents([params]);
    }
  });

  node_socket.on('ticket_reply_event_stop', function(params){
    // console.log('have reply stop here',params);
    if(params["user_id"] != current_userid && params['user_name'] != current_username){
      params["reply"] = true;
      RemoveAgents(params);
    }
  });

  node_socket.on('disconnect', function(){  
    // console.log('I am in disconnect');
    current_agents = {};
    current_agents_replying = {};
    ticket_status.connected = false;
    update_notification_ui_ticket(Object.keys(current_agents), Object.keys(current_agents_replying));
  });
};

