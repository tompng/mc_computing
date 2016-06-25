var VIDEO=false;
var selector = VIDEO ? ".page:not([data-video=false])" : ".page:not([data-video=true])"
onload=function(){
  if(!VIDEO)document.body.setAttribute('data-comment-show',true);
  var wrapper = document.querySelector('.page-wrapper');
  var firstPage = wrapper.querySelector('.page.active') || wrapper.querySelector(selector);
  firstPage.className = 'page active'
  beforePage(firstPage);
  resize();
  document.body.onresize=resize;
  document.body.onclick = function(e){
    if(e.pageX < window.innerWidth/2)nextPage(-1);
    else nextPage()
  }
  document.body.onkeydown=function(e){
    if(e.metaKey||e.ctrlKey||e.shiftKey)return;
    if(e.keyCode == 8 || e.keyCode == 37)nextPage(-1);
    else nextPage();
  }
  var blink=false;
  setInterval(function(){
    var dataname='data-blink-show'
    if(blink=!blink)document.body.setAttribute(dataname, true);
    else document.body.removeAttribute(dataname);
  },500)
}
function nextPage(dir){
  if(!dir)dir=1;
  var pages = [].concat.apply([], document.querySelectorAll(selector));
  var page = document.querySelector('.page.active');
  var index = pages.indexOf(page);
  var dstPage = pages[index+dir];
  if(dstPage){
    afterPage(page);
    page.className = 'page'
    dstPage.className = 'page active'
    beforePage(dstPage);
  }
}
function afterPage(page){
  var video = page.querySelector('video');
  if(!video)return;
  clearInterval(video.timer);
  video.pause();
  displays = page.querySelectorAll('[display-start]');
  for(var i=0;i<displays.length;i++){displays[i].style.display='none';}
}
function beforePage(page){
  var video = page.querySelector('video');
  if(!video)return;
  video.currentTime=0
  var delay=parseFloat(video.getAttribute('delay'))||0;
  var started=false;
  var time=new Date();
  var displays = [].concat.apply([], page.querySelectorAll('[display-start]'));
  displays.forEach(function(el){el.style.display='none';})
  video.timer = setInterval(function(){
    if((new Date()-time)>delay*1000&&!started){
      started=true;
      video.play();
    }
    var currentTime=delay+(video.currentTime||0);
    if(video.currentTime==0)currentTime=Math.min(currentTime, (new Date()-time)/1000)
    displays.forEach(function(el){
      var t=parseFloat(el.getAttribute('display-transition'));
      var ds=parseFloat(el.getAttribute('display-start'));
      var de=parseFloat(el.getAttribute('display-end'));
      if(isNaN(t))t=0.2;
      if(isNaN(ds))ds=-Infinity;
      if(isNaN(de))de=Infinity;
      var opacity;
      if(currentTime<ds)opacity=0;
      else if(currentTime<ds+t)opacity=(currentTime-ds)/t;
      else if(currentTime<de-t)opacity=1;
      else if(currentTime<de)opacity=(de-currentTime)/t;
      else opacity=0;
      if(opacity==0){el.style.display='none';el.style.opacity=0;}
      else{el.style.display='block';el.style.opacity=opacity;}
    })
  }, 10);
}
function resize(){
  var wrapper = document.querySelector('.page-wrapper');
  var w=window.innerWidth;
  var h=window.innerHeight;
  var pageW=800, pageH=450;
  var scale=Math.min(w/pageW, h/pageH);
  var cssTrans='translate('+[(w-pageW*scale)/2+'px', (h-pageH*scale)/2+'px']+')'
  var cssScale='scale('+[scale,scale]+')'
  return wrapper.style.transform=cssTrans+' '+cssScale;
}
