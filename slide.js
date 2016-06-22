onload=function(){
  var wrapper = document.querySelector('.page-wrapper');
  var firstPage = wrapper.querySelector('.page');
  firstPage.className = 'page active'
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
}
function nextPage(dir){
  if(!dir)dir=1;
  var pages = [].concat.apply([], document.querySelectorAll('.page'));
  var page = document.querySelector('.page.active');
  var index = pages.indexOf(page);
  var dstPage = pages[index+dir];
  if(dstPage){
    page.className = 'page'
    dstPage.className = 'page active'
  }
}

function resize(){
  var wrapper = document.querySelector('.page-wrapper');
  var w=window.innerWidth;
  var h=window.innerHeight;
  var pageW=800, pageH=600;
  var scale=Math.min(w/pageW, h/pageH);
  console.log(scale)
  var cssTrans='translate('+[(w-pageW*scale)/2+'px', (h-pageH*scale)/2+'px']+')'
  var cssScale='scale('+[scale,scale]+')'
  return wrapper.style.transform=cssTrans+' '+cssScale;
}
