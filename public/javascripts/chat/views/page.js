define([
  'collections/users',
  'views/layout',
  'views/sidebar',
  'views/chat',
  'views/visitor_list',
  'views/search/filter',
  'views/dashboard',
  'views/notifier'
], function(userCollection,layoutView,sidebarView,chatView,visitorList,filterView,dashboardView,notifierView){
  var $ = jQuery;
  window.userCollection = userCollection;
  var activityStatus = function(){
    window.active = true;
      $(window).blur(function(){
               window.active = false;
          }).focus(function(){
               window.active = true;
          });
  }
  var setupSound = function(){
      soundManager.createSound({
        id: 'alert',
        url: '/sound/alert.mp3'
      });
      soundManager.createSound({
        id: 'new_msg',
        url: '/sound/salient.mp3'
      });          
      window.startMusic = function(id){
        if(window.playSound){
          soundManager.play(id);
        }
      }  
  }
  var init = function(){
      window.dashboardView = dashboardView;
      users.fetch({
        success: function(){
          layoutView.render();
          sidebarView.render();
          chatView.render();
          dashboardView.render();
          listen();
        }
      });
      activityStatus();
      setupSound();
  }
  var listen = function(){
    $('body').on('click', function(){
        if($('#agent-list').is(':visible'))
           $('#agent-list').slideToggle('slow');
        if($('#visitor-list').is(':visible'))
          $('#visitor-list').slideToggle('slow');
        if($('#recent_container').is(':visible'))
           $('#recent_container').slideToggle('slow');
        if($('#userProfile').is(':visible'))
           $('#userProfile').slideToggle('slow');
        if($('#hiddenList').is(':visible'))
           $('#hiddenList').slideToggle('slow');
         if($('.updateUser').is(':visible'))
            $('.updateUser').hide();
    });

    $(document).on( 'mousewheel DOMMouseScroll', '.chat-messages', function(ev){
        if( ev.originalEvent ) ev = ev.originalEvent;
        var delta = ev.wheelDelta || -ev.detail;
        this.scrollTop += ( delta < 0 ? 1 : -1 ) * 30;
        ev.preventDefault();
    });

    if(typeof chat_action != "undefined"){
      if(chat_action=="archive"){
        filterView.render();
      }else{
        visitorList.fetch(chat_action);
      }
    }
  }
  return {init:init};
});