jQuery.noConflict()
 
!function( $ ) {

    // Meta fixes for other devices
    function fixMetas(firstTime) {
        $('meta[name="viewport"]').each(function(i, el) {
            el.content = firstTime
                ? 'width=device-width,minimum-scale=1.0,maximum-scale=1.0'
                : 'width=device-width,minimum-scale=0.25,maximum-scale=1.6'
        })
    }

    fixMetas(true)

    $("body").bind('gesturestart', fixMetas)

    $(function () {

        "use strict"

        var iframe = $('#iframe-preview'),
            responsive = $('#responsive-buttons')
        
        $(window).resize(function() {
            var ww = $(window).width(),
                topHeight = ww < 901 ? 0 : $("#preview-message").height()
            
            $('#preview-message').toggle(ww > 901)
            
            iframe.css({height: ($(window).height() - topHeight)})

        }).resize();

        responsive.find('a').bind("click", function(ev) {
            ev.preventDefault

            $(this).addClass('active').siblings().removeClass('active')

            var width = $(this).attr('data-width')
            if(width !== 'none')
                width = Number(width)+10

            iframe.css('max-width', width)
            return false
        });

    })

}(window.jQuery)