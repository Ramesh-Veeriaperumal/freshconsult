(function( $ ) {  

  jQuery.fn.jtabs = $.fn.jtabs = $.fn.tabs;

    //Global Veriables
    var nodeLength, lastNode = '';
    tabOverflow = function(chatId) {
    	$('#openChat').removeClass("animate");

      nodeLength = $('#tabs ul li').length;
      updateRel();
      if(nodeLength < 6){
    		lastNode = nodeLength;
    	}else{
    		//start hide tabs goes behind screen area
    		hideTab = nodeLength-2;
    		$( "#tabs" ).jtabs( "disable", hideTab);
    		
    		// Create/append overflow tab count
        var len = $('#hiddenList div').length;
    		if(len > 0){
    			$('#totalCount').html(len+1);
          $('#openChat').addClass("animate");
        }else{
    			overflowIndex();
    		}
    		
    		//Update the hidden chat list
        var tabid = $('li.ui-state-active').find('a').attr('href');
    		rel = $(tabid).attr('rel');
    		updateHiddenChat({
    			name:$('li.ui-state-active').prev(),
    			rel:hideTab+1
    		});
    		
    		//bind click events for the hidden chats
    		bindClicks();	
    	}
    },

    overflowIndex = function(){
    	$('#tabs').after('<div id="openChat" class="animate"><div id="hiddenList"></div><span id="totalCount">1</span></div>');
    },

    bindClicks = function(){
    		var clickObj = $('#hiddenList').children();
    		$.each(clickObj, function(){
    			$(this).unbind('click').on('click', function(){
    				var thisTab = eval($(this).attr('rel'));
    				var currentTab = getacitveTab();
    				$('li.ui-state-active').find('a:first-child').trigger('click');
      	    $( "#tabs" ).jtabs( "disable", currentTab-1);
    				$( "#tabs" ).jtabs( "enable", thisTab-1);
    				reConstruct({
    					that:this,
    					disabled:currentTab,
    					enabled:thisTab
    				});
    			});
    		});
    		$('#openChat').unbind('click').on('click', function(event){
          event.stopPropagation();
          if($('#agent-list').is(':visible'))
            $('#agent-list').slideToggle('slow');
          if($('#visitor-list').is(':visible'))
            $('#visitor-list').slideToggle('slow');
          if($('#recent_container').is(':visible'))
            $('#recent_container').slideToggle('slow');
          if($('#userProfile').is(':visible'))
            $('#userProfile').slideToggle('slow');
          $('#hiddenList').slideToggle("slow");
    		});
    },

    updateHiddenChat = function(object){
    		$('#hiddenList').append('<div rel="'+object.rel+'">'+object.name.find('a:first-child').html()+'</div>');
    		tabPosition();
    },

    $.fn.hasAttr = function(name) {  
      return this.attr(name) !== undefined;
    },

    getacitveTab = function(){
      if($('#tabs-group').find('li').hasClass('ui-state-active')){
      		return eval($('li.ui-state-active').attr('rel'));
      }else{
        var avTabs = $('#tabs-group li').not('.ui-state-disabled');
        return eval($(avTabs[0]).attr('rel'));
        
      }
    },

    tabPosition = function(){
  		if($('#tabs-group').find('li').hasClass('ui-state-active')){
      		var p = $('li.ui-state-active').position();
      		var chatId = $('li.ui-state-active').find('a').attr('href');
      		var leftVal = Math.round(p.left);
          $(chatId).css('left',leftVal+2);
      }
    },

    updateRel = function(){
      var Childs =  $('#tabs').find('ul').children();
      bottomBar(Childs.length);
    	var relCount = '1';
    	$.each(Childs, function(){
        $(this).attr('rel', relCount);
        var chatTab = $(this).find('a:first-child').attr('href');
        $(chatTab).attr('rel', relCount);
    		relCount++;
    	});
    },

    availableChat = function(chatid){
      var relNo = eval($("#tabs-chat-"+chatid).attr('rel'));
      var hiddenTabs = $('li.ui-state-disabled');
      var that,isHidden = false;
      $.each(hiddenTabs, function(){
        var relValue = $(this).attr('rel');
        if(relValue == relNo){
          isHidden = true;
          return;
        }
      });
      if(isHidden){
        var currentTab = getacitveTab();
        var totalList = $('#hiddenList').children();
        $.each(totalList, function(){
          if(eval($(this).attr('rel')) == relNo){
            that = this;
            return;
          }
        });
        $('li.ui-state-active').find('a:first-child').trigger('click');
        $( "#tabs" ).jtabs( "disable", currentTab-1);
        $( "#tabs" ).jtabs( "enable", relNo-1);

        reConstruct({
          that:that,
          disabled:currentTab,
          enabled:relNo
        });
      }else{
        $("#tabs").jtabs('select', relNo-1);
      }

      if($("#msg-box-"+chatid).is(":visible")){
        $("#msg-box-"+chatid).focus();
      }
      $('li.ui-state-active').find('a:first-child').removeClass("blink_background");
    },

    reConstruct = function(that){
        $(that.that).remove();
    		var Childs =  $('#tabs').find('ul').children();
    		$.each(Childs, function(){
    			if(eval($(this).attr('rel')) === eval(that.disabled)){
    				$('#hiddenList').append('<div rel="'+that.disabled+'">'+$(this).find('a:first-child').html()+'</div>')
    			}
    			if(eval($(this).attr('rel')) === eval(that.enabled)){
    				$(this).find('a:first-child').trigger('click');
            positionAllTabs();
    			}
    		});
    		bindClicks();
    },

    onTabRemoval = function(){
    		updateRel();
    		$('#openChat').removeClass("animate");
        var hiddenTabs = $('li.ui-state-disabled');
    		var toOpen = ''
    		$.each(hiddenTabs, function(){
    			toOpen = eval($(this).attr('rel'));
    			$( "#tabs" ).jtabs( "enable", toOpen-1);
    			$(this).find('a:first-child').trigger('click');
          positionAllTabs();
    			return false;
    		});
    		redoList(toOpen);
    		bindClicks();
    		var count = $('#hiddenList div').length;
    		if(count > 0){
    			$('#totalCount').html(count);
          $('#openChat').addClass("animate");
    		}else{
    			$('#openChat').remove();
    			$('#hiddenList').remove();
    		}
    		positionAllTabs();
    },

    positionAllTabs = function(){
    		var Childs =  $('#tabs').find('ul').children();
    		$.each(Childs, function(){
    			var chatTab = $(this).find('a:first-child').attr('href');
    			var pos = $(this).position();
    			var leftVal = Math.round(pos.left);
    			$(chatTab).css('left',leftVal+2);
      	});
    },

    redoList = function(relNo){
    		var totalList = $('#hiddenList').children();
    		$.each(totalList, function(){
    			if(eval($(this).attr('rel')) == relNo){
    				$(this).remove();
    			}
    		});
    		var redoData = $('li.ui-state-disabled');
    		var hiddenListHTML = '';
    		$.each(redoData, function(){
    			var tabName = $(this).find('a:first-child').html();
    			var relValue = $(this).attr('rel');
    			hiddenListHTML += '<div rel="'+relValue+'">'+tabName+'</div>';
    		});
    		$('#hiddenList').html(hiddenListHTML);
    },
    bottomBar = function(len){
      var bar = $('.sidebar_tabs_container');
      if(len>0){
        bar.removeClass('hide');
      }else{
        bar.addClass('hide');
      }
    }
})( jQuery ); 