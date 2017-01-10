// Creating a global RTS class
RTS = function(options){
  this.retryPeriod = 10000;
  this.timeoutPeriod = 30000;
  this.retryLimit = 4;
  this.channels = {};
  this.timeouts = {};
  this.callbacks = {};

  options = options || {};

  this.debug    = options["debug"]  || false;
  this.logger   = options["logger"] || window.console;
  this.origin   = options["origin"] || "https://pubsub.rtschannel.io/";
  this.nocookie = options["nocookie"] || false;
  this.onConnect = options["onConnect"] || function(){};
  this.onReconnect = options["onReconnect"] || function(){};
  this.onDisconnect = options["onDisconnect"] || function(){};
  this.disconnectCount = 0;
  
  options.accId ? this.accId = options.accId : this._throw("accId not provided");
  options.userId ? this.userId = options.userId : this._throw("userId not provided");
  options.token ? this.token = encodeURIComponent(options.token) : false;
  options.webURL ? this.webURL = options.webURL :  false;
  options.leaveOnUnload ? this.leaveOnUnload() :  false;

  if(typeof window.PUBSUBio == "undefined" && window.PUBSUBio != null){
    this._throw("Could not find the Socket IO object for RTS!")
  }
  this.io = window.PUBSUBio;

  this.initializeSocket();
  this.initializeSocketListeners();
}

/**
 * The Main RTS Object
 * @type {Object}
 */
RTS.prototype = {
  constructor: RTS,

  initializeSocket: function(){
    this.log("Initializing socket connection...");
    var queryParams = ["accId=", this.accId, "&userId=", this.userId, "&token=", this.token].join("");
    if(this.nocookie === true){
      queryParams += '&nocookie=true'
    }
    var manager = this.io.Manager(this.origin + '?' + queryParams,{
      "forceBase64" : true, 
      // "reconnectionAttempts": this.retryLimit
    });
    
    // Storing the socket instance in the object itself
    this.socket = manager.socket('/');
  },

  initializeSocketListeners: function(){
    this.log("Binding the socket listeners...");
    this.socket.on("connect", this._onConnect.bind(this));
    this.socket.on('reconnecting', this._onReconnecting.bind(this));
    this.socket.on('reconnect', this._onReconnect.bind(this));
    this.socket.on('disconnect', this._onDisconnect.bind(this));
    this.socket.on('message', this._onMessage.bind(this));
  },

  /**
   * Subscribes the user to a channel
   * @param  {string}   channelName    The name of the channel to be subscribed
   * @param  {Function}   messageHandler Called when a message is received on this channel
   * @param  {Function} callback       
   */
  subscribe: function(channelName, messageHandler, callback){
    this.log("Trying to subscribe to channel: ",channelName);
    var self = this;
    // Subscribe to a channel here
    if(!this._connectionCheck(callback)){ return; }
    if(this._isChannelSubscribed(channelName)){ 
      var str = "Already subscribed to "+channelName;
      this.log(str);
      self.channels[channelName] = { 
        connected: true,
        onMessage: messageHandler
      };
      if(callback) callback(null, str);
      return;
    }

    
    // Send a subscription message
    this._sendMessage({
      event: "subscribe",
      channel: channelName
    }, function(err,result){
      if(err){
        self.log("Could not subscribe to channel: ", err, channelName);
      }

      self.channels[channelName] = { 
        connected: true,
        onMessage: messageHandler
      };

      if(callback) callback(err,result);
    });
  },

  unsubscribe: function(channelName,callback){
    // Unsubsribe from a particular channel
    if(!this._connectionCheck(callback)){ return; }
    if(!this._isChannelSubscribed(channelName,callback)){ return; }

    var self = this;
    // Send an unsubscription message
    this._sendMessage({
      event: "unsubscribe",
      channel: channelName
    }, function(err,result){
      if(err){
        self.log("Could not unsubscribe from channel: ", err, channelName);
      } else {
        delete self.channels[channelName];
      }

      if(callback) callback(err,result)
    });
  },

  // The client also gets purged after this call.
  // Make sure you reconnect to the RTS server
  // TODO: this is probably the last thing anyone will do on RTS. Should we alias it to something more serious.
  unsubscribeAll: function(callback){
    // Unsubscribe from all the channels
    if(!this._connectionCheck){ return; }

    // Send a unsubscription message
    this._sendMessage({
      event: "unsubscribeall"
    });

    // Remove all channels
    this.channels = {};

    if(callback) callback(null, this.channels);
  },

  // Alias as it makes more sense
  destroy: function(callback){
    this.unsubscribeAll(callback);
  },

  publish: function(options, callback){
    // Publish something to the socket
    if(!this._connectionCheck){ return; }
    if(!this._isChannelSubscribed(options.channelName)){ return; }

    // Send the message
    this._sendMessage({
      event: "send",
      channel: options.channelName,
      msg: JSON.stringify(options.message),
      opt: !!options.persist ? 1 : 0
    });

    this.log("Message sent", options.message);
    if(callback) callback(null, "Message Sent")
  },

  channelWho: function(channelName, options, callback){
    // Get all users subscribed to a channel
    // Publish something to the socket
    if(!this._connectionCheck(callback)){ return; }

    // Send the message
    var self = this;
    this._sendMessage({
      event: "channel_who",
      channel: channelName,
      msg: JSON.stringify(options)
    }, function(err,result){
      if(err){
        self.log("Could not fetch channel_who: ", err, channelName);
      }
      if(callback) callback(err,result);
    });
  },

  userWhere: function(callback){
    // Get all channels subscribed by a user
    if(!this._connectionCheck(callback)){ return; }

    var self = this;
    this._sendMessage({
      event: "user_where"
    }, function(err,result){
      if(err){
        self.log("Could not fetch user_where: ", err);
      }
      if(callback) callback(err,result);
    });
  },

  on: function(){
    // bind an event to a channel
  },

  off: function(){
    // Unbind an event from a channel
  },

  save: function(channelName, data, callback){
    // Save any data for the user on a channel
    if(!this._connectionCheck()){ return; }
    if(!this._isChannelSubscribed(channelName)){ return; }

    var self = this;
    this._sendMessage({
      event: "save",
      channel: channelName,
      msg: JSON.stringify(data)
    }, function(err,result){
      if(err){
        self.log("Could not fetch user_where: ", err);
      } else {
        self.log("Saved data.", data);
      }

      if(callback) callback(err,result)
    });
  },

  fetch: function(channelName, userId, callback){
    // Set the state for the user on a channel
    if(!this._connectionCheck(callback)){ return; }
    if(!this._isChannelSubscribed(channelName, callback)){ return; }

    var self = this;
    this._sendMessage({
      event: "fetch",
      channel: channelName,
      userId: userId
    }, function(err,result){
      if(err){
        self.log("Could not fetch user data: ", err);
      }
      if(callback) callback(null, result);
    });
  },

  pull: function(channelName, from, callback){
    // Pull messages by last message id.
    if(!this._connectionCheck(callback)){ return; }
    if(!this._isChannelSubscribed(channelName, callback)){ return; }

    var self = this;
    this._sendMessage({
      event: "pull",
      channel: channelName,
      from: from
    }, function(err,result){
      if(err){
        self.log("Could not execute a pull: ", err);
      }
      if(callback) callback(null, result);
    });
  },

  pullRange: function(channelName, from, callback){
    // Pull messages by range.
    if(!this._connectionCheck(callback)){ return; }
    if(!this._isChannelSubscribed(channelName, callback)){ return; }

    var self = this;
    this._sendMessage({
      event: "pull_range",
      channel: channelName,
      from: from
    }, function(err,result){
      if(err){
        self.log("Could not execute a pull range: ", err);
      }
      if(callback) callback(null, result);
    });
  },

  sendAck: function(channelName, messageId, userId, callback){
    // if(this.webURL){
    //   var url = this.webURL+'/ack/' + [data.accId,data.channel,this.userId,data.id].join('/');
    //   var xhr = new XMLHttpRequest();
    //   xhr.open('PUT',url ,true);
    //   xhr.setRequestHeader('Content-Type', 'application/json');
    //   xhr.send();
    // }
    
    // Pull messages by range.
    if(!this._connectionCheck(callback)){ return; }
    if(!this._isChannelSubscribed(channelName, callback)){ return; }

    this._sendMessage({
      event: "ack",
      channel: channelName,
      msgId: messageId,
      userId: userId
    });
    
    if(callback) callback(null, "Sent ack message");
  },

  createChannel: function(options, callback){
    options.rts = this;
    callback(null, new RTSChannel(options))
  },

  leaveOnUnload: function(){
    // Close the connection right before the page is unloaded.
    var self = this;
    if (window.addEventListener) {
      window.addEventListener("beforeunload", function () {
        self.close();
      }, false);
    } else {
      window.attachEvent("onbeforeunload", function (){
        self.close();
      });
    }
  },

  close:  function(callback){
    // Send a close event on the socket
    if(!this._connectionCheck(callback)){ return; }

    this._sendMessage({
      event: "close",
    });

    if(callback) callback(null,"Connection Closed");
  },

  disconnect: function(){
    // Disconnect the socket
    this.socket.io.disconnect();
  },

  reconnect: function(){
    // Attempt to reconnect the socket
    this.socket.io.connect();
  },

  log: function(){
    // Custom log function
    if(this.debug === true && this.logger){
      var args = Array.prototype.slice.call(arguments);
      args.unshift("RTS:");
      args.unshift(arguments.callee.caller.name);
      args.unshift((new Date()).toLocaleTimeString());
      this.logger.log.apply(this.logger, args);
    }
  },

  // Private functions
  _throw: function(errorString){
    throw new Error(errorString)
  },

  _generateUid: function(){
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        var r = Math.random()*16|0, v = c == 'x' ? r : (r&0x3|0x8);
        return v.toString(16);
    });
  },

  _connectionCheck: function(callback){
    if(this.connected === false){
      var errString = "Not performing action as client is not connected.";
      this.log(errString)
      if(callback) callback(errString);
    }
    return this.connected;
  },

  _isChannelSubscribed: function(channelName, callback){
    if(!this.channels[channelName]){
      var errString = "Channel "+channelName+" is not subscribed yet.";
      this.log(errString);
      if(callback) callback(errString);
    }
    return !!this.channels[channelName]
  },

  _startTimeoutErrorTimer: function(callbackId){
    // Starts a timer for `timeoutPeriod` and triggers the callback specified by the callbackId
    // if not cleared before the timeoutPeriod.
    self = this;
    self.timeouts[callbackId] = setTimeout(function(){
      if(self.callbacks[callbackId]){
        self.callbacks[callbackId]("Timeout Error");
      }
      delete self.timeouts[callbackId];
    }, this.timeoutPeriod)
  },

  _sendMessage: function(data,callback){
    if(callback){
      // Store the callback for invocation later.
      var callbackId = this._generateUid();
      this.callbacks[callbackId] = callback;
      data.clientId = callbackId;

      // Start the `timeout error` timer
      this._startTimeoutErrorTimer(callbackId);
    }

    data.accId = this.accId;
    this.log("Sending data", data);
    this.socket.emit("message", JSON.stringify(data));
  },

  _onConnect: function(){
    self = this;
    this.log("Socket Connected");
    this.connected = true;
    this.socket_id = this.socket.id;
    this.userWhere(function(err,result){
      if(typeof result!="undefined" && result.msg && !!result.Local && JSON.parse(result.msg).List && JSON.parse(result.msg).List.length){
        var channels = JSON.parse(result.msg).List;
        for (var i = channels.length - 1; i >= 0; i--) {
          self.channels[channels[i]] = {connected:true};
        }
        self.log("RTS Channels:",self.channels);
      }
      self.onConnect();
    });
  },

  _onReconnecting: function(){
    this.log("Socket reconnecting");
  },

  _onReconnect: function(){
    this.log("Socket reconnected");
    window.clearTimeout(this.disconnect_timer);
    this.connected = true;
    this.onReconnect();
  },

  _onDisconnect: function(type) {
    // A timer of 3 secs added before setting the state to disconnected as a buffer time.
    this.log("Disconnect timer begins...");
    self = this;
    this.disconnect_timer = window.setTimeout(function(){
      self.log("Disconnected");
      self.connected = false;
      // Clear subscribed channels
      self.channels = {};
      self.disconnectCount++;
      self.onDisconnect(type);
    }, 3000);
  },

  _onMessage: function(data){
    try {
      data = JSON.parse(data);
    } catch (err) {
      this.log("MessageParseError", data)
      return;
    }

    this.log("Received Data.", data);
    this._onEvent(data);
  },

  _onEvent: function(data){
    if(data.clientId){
      this.log("Event Data",data.event, data.msg, data);
      if(this.timeouts[data.clientId]){
        // Clear the timer
        clearTimeout(this.timeouts[data.clientId]);
        
        // Remove the timer from timeouts object
        delete this.timeouts[data.clientId];
      }
      
      if(this.callbacks[data.clientId]){
        if(data.err === "" || !data.err){
          // Invoke the callback based on clientId
          this.callbacks[data.clientId](null,data);
        } else {
          // Invoke the error callback based on clientId
          this.log("Error: ", data)
          this.callbacks[data.clientId](data.err);
        }
        
        // Remove callback from callbacks object
        delete this.callbacks[data.clientId];
      }
    } 

    if(data.event == "send" && 
       data.channel && 
       this.channels[data.channel] && 
       typeof this.channels[data.channel].onMessage == "function"){
      this.channels[data.channel].onMessage(data);
    } 
  },
}

/*
  options: {
    rts: RTS, // A connected RTS instance
    name: "", // Name of the channel
    onSubscribe: function(){}
  }
 */
RTSChannel = function(options){
  if(typeof options !="object" || !options){
    throw new Error("RTSChannel needs an options object"); 
    return
  }

  if(typeof options.rts == "undefined" || !options.rts || !options.rts.connected){
    throw new Error("RTSChannel needs a connected RTS instance in the options object to initialize");
    return
  }

  if(typeof options.name == "undefined" || !options.name){
    throw new Error("RTSChannel needs a `name` parameter in the options object"); 
    return
  }

  this._name = options.name;
  this._rts = options.rts;

  // Subscribe to this channel
  this.subscribe(options.onMessage, options.onSubscribe);
}

//TODO: We could also do the `arguments` param magic here.
RTSChannel.prototype = {
  constructor: RTSChannel,

  subscribe: function(messageHandler, callback){
    this._rts.subscribe(this._name, messageHandler, callback);
  },

  unsubscribe: function(callback){
    this._rts.unsubscribe(this._name, callback);
  },

  publish: function(message, callback){
    this._rts.publish({
      channelName: this._name,
      message: message 
    }, callback);
  },

  who: function(options,callback){
    this._rts.channelWho(this._name, options, callback);
  },

  save: function(data, callback){
    this._rts.save(this._name, data, callback);
  },

  fetch: function(userId, callback){
    this._rts.fetch(this._name, userId, callback);
  },

  pull: function(from, callback){
    this._rts.pull(this._name, from, callback);
  },

  pullRange: function(from, callback){
    this._rts.pullRange(this._name, from, callback);
  },

  sendAck: function(messageId, userId, callback){
    this._rts.sendAck(this._name, messageId, userId, callback);
  }

}