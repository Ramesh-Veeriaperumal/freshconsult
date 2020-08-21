// TO BE REMOVED : OLD UI DEPRECATION
window.App = window.App || {};

(function ($) {
  "use strict";

  App.FalconInvite = {
    initialize: function(){
      var $this = this;
      $('#falcon-invite-modal').modal({ backdrop: 'static', keyboard: false});
      $("#falcon-invite-modal #try-later").on("click", function(){ 
        $this.skipFalcon()
      })
    },
    skipFalcon: function(){
      this.repositionAndCollapseModal();
      $.post('/disable_falcon');
    },
    //collapse modal into 'switch to the new look' button in header
    repositionAndCollapseModal: function(){
      var falconInviteModal = $('#falcon-invite-modal');
      var falconInviteModalWidth = falconInviteModal.outerWidth();
      var swithUIButton = $('#ui_toggle');
      var swithUIButtonPosition = swithUIButton.offset();
      var swithUIButtonHeight = swithUIButton.outerHeight();
      var swithUIButtonWidth = swithUIButton.outerWidth();
      falconInviteModal.animate({
        top: "0%",
        left: "0%",
        marginTop: (swithUIButtonPosition.top + (swithUIButtonHeight/2)) + "px",
        marginLeft: (swithUIButtonPosition.left - falconInviteModalWidth + (swithUIButtonWidth/2)) + "px"
      }, 0, function(){
        $(this).hide('size', { origin: ["top", "right"] }, 300, function(){
          $(this).modal("toggle")
        });
      })
    }
  };
}(window.jQuery));

jQuery(document).ready(function(){
  App.FalconInvite.initialize();
});