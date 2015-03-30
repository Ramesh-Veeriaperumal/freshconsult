
document.addEventListener('chat onConnect', function(){
    bindEvent();
}, false);

document.addEventListener('chat disConnect', function(){
    unbindEvent();
}, false);
var bindEvent = function(){
    window.liveChat.chatIcon = true;
    jQuery('body').on('click','.list_agents_replying .agent_detail',function (){
        if(!jQuery('.agent_detail').hasClass('clickDisable')){
            jQuery('.agent_detail').addClass('clickDisable');
            var id = jQuery('.agent_detail').attr('id');
            window.agentCollision.Chat(id);
            setTimeout(function() {
                jQuery('.agent_detail').removeClass('clickDisable');
            },3500);
        }
    });

    jQuery('body').on('hover','.list_agents_replying .agent_detail',function (){
        jQuery('.agent_detail').css({'cursor':'pointer'});
        jQuery('.more_agents').css({'cursor':'pointer'});
    });

    jQuery('body').on('mouseleave','.list_agents_replying .agent_detail a',function(){
        jQuery('.twipsy.in').hide();
    })

    jQuery('body').on('hover','.hover_card .agent_name',function(e){
        jQuery('.agent_name').css({'cursor':'pointer'});
    });

    jQuery('body').on('click','.hover_card .agent_name',function(e){
        var id = jQuery(this).attr('id');
        window.agentCollision.Chat(id);
        jQuery('.hover-card-agent').parent().remove();
        jQuery('.twipsy.in').hide();
    }) ;  
};

var unbindEvent = function(){
    jQuery('body').off('click','.hover_card .agent_name');
    jQuery('body').off('click','.list_agents_replying .agent_detail');
    window.liveChat.chatIcon = false;
}; 



  
