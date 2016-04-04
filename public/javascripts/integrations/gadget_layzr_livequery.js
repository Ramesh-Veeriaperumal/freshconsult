//This is taken from livequery_init.js, please maintain there too.
var layzr;
$(".image-lazy-load img").livequery(
  function(){
    layzr = new Layzr({
      container: null,
      selector: '.image-lazy-load img',
      attr: 'data-src',
      retinaAttr: 'data-src-retina',
      hiddenAttr: 'data-layzr-hidden',
      threshold: 0,
      callback: function(){
        $(".image-lazy-load img").css('opacity' , 1);
      }
    });
  },
  function() {
    layzr._destroy()
  }
);