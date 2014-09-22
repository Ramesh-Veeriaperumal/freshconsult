/**
 * © Copyright FreshDesk Inc., 2014
 * Idle Detector 
 *
 * Idle Detector's job is to know when a user is inactive for extended period of time
 * If so, it disconnects the socket in the inactive tab
 * If the tab happens to be the last active tab the user is logged in, it makes him/her offline
 * It brings the user back to the original state once the tab is used again (say, if the user comes back)
 */
var IdleDetector;

(function ($) {
  IdleDetector = function(opts) {
    this.SLEEP_TIMEOUT = opts.SLEEP_TIMEOUT || window.SLEEP_TIMEOUT || -1;
    this.IDLE_TIMEOUT = opts.IDLE_TIMEOUT || window.IDLE_TIMEOUT || -1;
    this.enabled = opts.enabled || true;
    if (this.SLEEP_TIMEOUT < 0 || this.IDLE_TIMEOUT < 0) { this.enabled = false };
    this.events = opts.events || ['mousemove', 'keydown', 'mousewheel'];
    this.resetDetector(true);
    this.socketDisconnector();
  }

  IdleDetector.prototype.resetDetector = function(connected) {
    // If a timeout exists, clear it
    if(this.delayToBind_T_O) clearTimeout(this.delayToBind_T_O);
    if (this.enabled) {
      // On timeout, bind event listeners on the body
      this.delayToBind_T_O = setTimeout(function() {
        console.log('Turn on handlers and wake up');
        // In a timeout callback. Get reference from global variable
        var self = freshfonesocket.idleDetector;
        // Prevents any errors caused by race condition in script loading
        // Any number of events can be listened to by just appending them to the events list
        self.binder.apply(self);
      }, (connected? this.SLEEP_TIMEOUT: 0)); // When connected, execute after IDLE_TIME, else immediately
    } else {
      // If a timeout already exists, clear it
      if (this.idleSocket_T_O) clearTimeout(this.idleSocket_T_O);
    }
  };

  IdleDetector.prototype.binder = function() {
    // This function binds event listeners
    var self = this;
    for (var ev = self.events.length - 1; ev >= 0; ev--) {
      // Bind every event passed to the function to the event listener
      $('body').on(self.events[ev], self.handler);
    };
    // If a timeout already exists, clear it
    if (this.idleSocket_T_O) clearTimeout(this.idleSocket_T_O);
    this.idleSocket_T_O = setTimeout(function() {
      // In a timeout callback. Get reference from global variable
      var self = freshfonesocket.idleDetector;
      // If the user has been idle, and his socket is connected, let the server know this tab has been inactive
      if (typeof (freshfonesocket ) != 'undefined' && freshfonesocket.freshfone_socket_channel.connected) {
        console.log('Tell the server that this socket is idle')
        freshfonesocket.freshfone_socket_channel.emit('idle');
        // Setup the Idle detector again, this time when the socket is offline
        self.resetDetector(false);
      }
    }, this.IDLE_TIMEOUT);
  };

  IdleDetector.prototype.handler = function() {
    // This function is called when the associated event has occured
    console.log('When this happens, turn off handlers and go to sleep');
    var self = freshfonesocket.idleDetector;
    // In order to call reconnect
    // 1) This should have been called after the tab went idle
    // 2) The socket should be disonnected (To avoid reconnecting already connected socket)
    if (!freshfonesocket.freshfone_socket_channel.connected) { 
      // Reconnecting socket
      freshfonesocket.freshfone_socket_channel.io.reconnect();
      freshfoneuser.reset_presence_on_reconnect();

      console.log('Get status of the user from server and set it')
      freshfoneuser.get_presence(function(err, status) {
        if (!err) { 
          console.log('Presence status received from server is ' + status);
          freshfonesocket.toggleUserStatus(status);
        }
      });
    }
    for (var ev = self.events.length - 1; ev >= 0; ev--) {
      console.log('Turn off all the event listeners because the tab is active. No point in wasting CPU cycles')
      $('body').off(self.events[ev], self.handler);
    };
    if (typeof (freshfonesocket ) != 'undefined') {
      // Reset the Idle detector. Check again after some time
      clearTimeout(self.idleSocket_T_O);
      self.resetDetector(true);
    }
  };

  IdleDetector.prototype.disable = function() {
    this.enabled = false;
    this.handler(); // Detaches all event listeners and since enabled is set to false, removes all timeouts
  };

  IdleDetector.prototype.enable = function() {
    this.enabled = true;
    this.resetDetector(true);
  };

  // Creates handler to `disconnect_idle_tab` sent by the server when tab idleness is notified
  IdleDetector.prototype.socketDisconnector = function() {
    if(typeof (freshfonesocket ) != 'undefined') {
      freshfonesocket.freshfone_socket_channel.on('disconnect_idle_tab', function(data) {
        console.log('The server emits this message when the client reports the tab as idle')
        freshfonesocket.disconnect();
        // If this is the last tab, and the user is currently online
        if(data.last_tab && freshfoneuser.online) {
          // User status should be changed to offline only if the last active tab goes offline
          console.log('Server reports that this is the last tab, _and_ is idle');
          freshfonesocket.toggleUserStatus(userStatus.OFFLINE)
        }
      });
    };
  };
}(jQuery));
