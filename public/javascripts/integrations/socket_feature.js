/*global
 FdSocket, Freshdesk, Class, jQuery, document, console, location
 */
var FreshdeskSocket = function (options) {
  if (!(this instanceof FreshdeskSocket)) { return new FreshdeskSocket(options); }
  this.feature_name = options.name;
  this.activePageRegexes = options.activePageRegexes;
  this.socket = FdSocket.connect(this.feature_name);
  if (this.activePageRegexes) {
    this.registerForPageChange();
  }
};
FreshdeskSocket.prototype = {
  registerForPageChange: function() {
    jQuery(document).bind('pjax:beforeReplace', this.onPageChange.bind(this));
  },

  onPageChange: function() {
    console.log("location path" + location.pathname);

    if (!this.shouldBeConnected()) {
      this.socket.disconnect();
    } else if (!this.socket.connected) {
      this.socket.connect();
    }
  },

  shouldBeConnected: function() {
    var matches = this.activePageRegexes.filter(function(regex) {
      return !!regex.exec(location.pathname);
    });
    return !!matches.length;
  }
};
