// Web paneli: Belle Remote canli ekran (PC'ler + sunucu tarayicisi) — modern mobil ve masaustu tarayicilar icin.
// Ayni Belle Remote protokolu (WebSocket kopru /panel/ws); Nokia uygulamasi bundan etkilenmez.
//  - Mobil / PC secimi (ilk acilista sorulur, sonra degistirilebilir)
//  - Mobil: "Dokunmatik" (dokunulan yere tikla) ya da "Touchpad" (parmakla imleci goreli surukle) kipi,
//    iki parmakla yakinlastir/kaydir (yerel), iki parmak dikey kaydirma = tekerlek, uzun bas = sag tik,
//    klavye dugmesi telefonun klavyesini acar (imlec kipinde otomatik), ozel tuslar cubugu
//  - PC: fare (sol/sag/orta, surukle, tekerlek), klavye dogrudan, tam ekran
//  - Cozunurluk (en fazla 1080p), kare hizi (60 fps'e kadar) ve kalite ayri ayri secilir
function sayfa(hedef, tar) {
    const H = JSON.stringify(hedef), T = tar ? "true" : "false";
    return '<!DOCTYPE html><html lang="tr"><head><meta charset="utf-8">' +
'<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover">' +
'<meta name="theme-color" content="#111"><meta name="mobile-web-app-capable" content="yes"><meta name="apple-mobile-web-app-capable" content="yes">' +
'<title>' + (tar ? "Sunucu tarayıcısı" : String(hedef).replace(/[<>&"]/g, "")) + ' • Belle Remote</title><style>' +
'*{box-sizing:border-box;-webkit-tap-highlight-color:transparent}html,body{margin:0;height:100%;background:#0b0c0e;color:#e8eaed;font:15px system-ui,-apple-system,Segoe UI,Roboto,sans-serif;overflow:hidden;overscroll-behavior:none}' +
'#ust{position:fixed;left:0;right:0;top:0;height:46px;display:flex;align-items:center;gap:6px;padding:0 8px;padding-top:env(safe-area-inset-top);background:#16181c;border-bottom:1px solid #2a2d33;z-index:5}' +
'#ust .ad{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:0 1 auto;max-width:28vw}#durum{color:#9aa0a6;font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;flex:1}' +
'button,select{font:inherit;color:#e8eaed;background:#2a2d33;border:0;border-radius:9px;padding:7px 11px;cursor:pointer;touch-action:manipulation}button:active{background:#3c4043}button.ac{background:#1a73e8}' +
'select{padding:6px 8px}#alan{position:fixed;left:0;right:0;top:46px;bottom:0;overflow:hidden;touch-action:none;background:#000}' +
'body.mobil #alan{bottom:calc(52px + env(safe-area-inset-bottom))}#sahne{position:absolute;left:0;top:0;transform-origin:0 0}' +
'#vid{display:none;pointer-events:none}#ekran{display:block;user-select:none;-webkit-user-drag:none;-webkit-touch-callout:none;pointer-events:none}' +
'#imlec{position:absolute;width:22px;height:22px;margin:-2px 0 0 -2px;pointer-events:none;display:none;z-index:2}' +
'#alt{position:fixed;left:0;right:0;bottom:0;display:none;gap:5px;padding:6px 6px calc(6px + env(safe-area-inset-bottom));background:#16181c;border-top:1px solid #2a2d33;overflow-x:auto;z-index:5;scrollbar-width:none}' +
'body.mobil #alt{display:flex}#alt button{flex:0 0 auto;padding:8px 11px}' +
'#ayar,#secim{position:fixed;inset:0;background:#000b;display:none;align-items:center;justify-content:center;z-index:10}' +
'.kutu{background:#1c1e22;border-radius:14px;padding:18px;width:min(460px,92vw);max-height:88vh;overflow:auto}.kutu h3{margin:0 0 12px}.kutu label{display:block;margin:12px 0 4px;color:#9aa0a6;font-size:13px}.kutu select{width:100%}' +
'.iki{display:flex;gap:10px;margin-top:14px}.iki button{flex:1;padding:14px}.secim-k{flex:1;text-align:center;padding:18px 8px;border-radius:12px;background:#2a2d33;cursor:pointer}.secim-k b{display:block;font-size:17px;margin:6px 0 2px}.secim-k:active{background:#3c4043}' +
'#gizli{position:fixed;left:0;bottom:0;width:1px;height:1px;opacity:0;font-size:16px;border:0;padding:0}' +
'#tar{display:none;flex:1;gap:6px}body.tar #tar{display:flex}#adres{flex:1;min-width:0;font:inherit;background:#0b0c0e;color:#e8eaed;border:1px solid #2a2d33;border-radius:9px;padding:6px 10px}' +
'body.tar #durum{display:none}.ipucu{position:fixed;left:50%;transform:translateX(-50%);bottom:70px;background:#000d;padding:8px 14px;border-radius:10px;font-size:13px;z-index:6;pointer-events:none;transition:opacity .3s}' +
'@media (max-width:560px){#ust .ad{display:none}}' +
'</style></head><body>' +
'<div id="ust"><button onclick="location=\'/panel/uzak\'" title="Geri">‹</button><span class="ad">' + (tar ? "Sunucu tarayıcısı" : String(hedef).replace(/[<>&"]/g, "")) + '</span>' +
'<form id="tar" onsubmit="git();return false"><button type="button" onclick="kom(\'geri\')">←</button><button type="button" onclick="kom(\'yenile\')">⟳</button><input id="adres" placeholder="Adres ya da arama" autocapitalize="off" autocomplete="off"></form>' +
'<span id="durum">Bağlanıyor…</span><button id="kipD" onclick="kipDegis()" style="display:none">Dokunmatik</button><button onclick="klavye()" title="Klavye">⌨</button><button onclick="ayarAc()" title="Ayarlar">⚙</button><button onclick="tam()" title="Tam ekran">⛶</button></div>' +
'<div id="alan"><div id="sahne"><img id="ekran" draggable="false" alt=""><canvas id="vid"></canvas><svg id="imlec" viewBox="0 0 22 22"><path d="M2 2 L2 18 L6.5 13.8 L9.6 20.5 L12.4 19.2 L9.4 12.8 L15.5 12.8 Z" fill="#fff" stroke="#000" stroke-width="1.4"/></svg></div></div>' +
'<div id="alt"><button onclick="tus(\'esc\')">Esc</button><button onclick="tus(\'tab\')">Tab</button><button id="mCtrl" onclick="mod(\'ctrl\')">Ctrl</button><button id="mAlt" onclick="mod(\'alt\')">Alt</button><button id="mShift" onclick="mod(\'shift\')">Shift</button><button id="mWin" onclick="mod(\'win\')">Win</button>' +
'<button onclick="tus(\'left\')">◀</button><button onclick="tus(\'up\')">▲</button><button onclick="tus(\'down\')">▼</button><button onclick="tus(\'right\')">▶</button><button onclick="tus(\'enter\')">Enter</button><button onclick="tus(\'backspace\')">⌫</button><button onclick="tus(\'delete\')">Del</button>' +
'<button onclick="tik(\'R\')">Sağ tık</button><button onclick="tus(\'ctrl+c\')">Kopyala</button><button onclick="tus(\'ctrl+v\')">Yapıştır</button><button onclick="tus(\'ctrl+z\')">Geri al</button>' +
'<button onclick="tus(\'f5\')">F5</button><button onclick="tus(\'alt+tab\')">Alt+Tab</button><button onclick="tus(\'win+d\')">Masaüstü</button>' + (tar ? '' : '<button onclick="tus(\'ctrl+alt+delete\')">C+A+Del</button>') + '<button onclick="yakinSifir()">1:1</button></div>' +
'<input id="gizli" autocapitalize="off" autocomplete="off" autocorrect="off" spellcheck="false">' +
'<div id="secim"><div class="kutu"><h3>Bu cihaz hangisi?</h3><div class="iki" style="margin-top:4px"><div class="secim-k" onclick="cihazSec(\'mobil\')">📱<b>Mobil</b><span style="color:#9aa0a6;font-size:13px">Dokunmatik, touchpad, ekran klavyesi</span></div>' +
'<div class="secim-k" onclick="cihazSec(\'pc\')">🖥️<b>PC</b><span style="color:#9aa0a6;font-size:13px">Fare ve klavye doğrudan</span></div></div><p style="color:#9aa0a6;font-size:13px;margin:14px 0 0">Ayarlar\'dan sonra değiştirebilirsiniz.</p></div></div>' +
'<div id="ayar"><div class="kutu"><h3>Görüntü ve kontrol</h3>' +
'<label>Çözünürlük (genişlik)</label><select id="aCoz"><option value="oto">Otomatik (bu ekrana göre)</option><option>640</option><option>800</option><option>960</option><option>1280</option><option>1366</option><option>1600</option><option value="1920">1920 (1080p)</option></select>' +
'<label>Kare hızı (fps)</label><select id="aFps"><option>2</option><option>5</option><option>8</option><option>10</option><option>12</option><option>15</option><option>20</option><option>24</option><option>30</option><option>45</option><option>60</option></select>' +
'<label>Görüntü biçimi</label><select id="aBic"><option value="h264">H.264 video — akıcı, az veri (önerilen)</option><option value="jpeg">JPEG kareler — eski yöntem</option></select><label>Görüntü kalitesi</label><select id="aKal"><option value="30">Düşük (30) — en az veri</option><option value="45">Orta-düşük (45)</option><option value="60">Orta (60)</option><option value="75">Yüksek (75)</option><option value="85">Çok yüksek (85)</option><option value="92">En yüksek (92)</option></select>' +
'<label>Cihaz</label><select id="aCihaz"><option value="mobil">Mobil (dokunmatik)</option><option value="pc">PC (fare / klavye)</option></select>' +
'<label>Dokunma kipi (mobil)</label><select id="aKip"><option value="dokun">Dokunmatik: dokunduğum yere tıkla</option><option value="pad">Touchpad: parmakla imleci kaydır</option></select>' +
'<p style="color:#9aa0a6;font-size:12px">' + (tar ? 'Sunucu tarayıcısı 60 fps / 1080p\'ye kadar istenebilir; gerçek hız sunucunun gücüne bağlıdır.' : 'PC uygulaması 60 fps / 1080p\'ye kadar verir; gerçek hız PC\'nin ve internetin hızına bağlıdır. Çözünürlük ve kare hızı birbirinden bağımsızdır.') + '</p>' +
'<div class="iki"><button onclick="ayarKapat(false)">Vazgeç</button><button class="ac" onclick="ayarKapat(true)">Uygula</button></div></div></div>' +
'<script>\n' +
'var HEDEF=' + H + ',TAR=' + T + ';\n' + ISTEMCI + '\n</script></body></html>';
}

// ---- tarayici tarafi (istemci) ----
const ISTEMCI = String.raw`
var A={};try{A=JSON.parse(localStorage.getItem('belleUzak')||'{}')}catch(e){}
function kaydet(){try{localStorage.setItem('belleUzak',JSON.stringify(A))}catch(e){}}
var ws,img=document.getElementById('ekran'),vid=document.getElementById('vid'),gorEl=img,alan=document.getElementById('alan'),sahne=document.getElementById('sahne'),imlecEl=document.getElementById('imlec'),gizli=document.getElementById('gizli');
var buf=new Uint8Array(0),eskiUrl=null,dogal={w:0,h:0},cx=5000,cy=5000,modlar={},sonM=0;
var yak={s:1,x:0,y:0};    // yerel yakinlastirma (iki parmak)
if(TAR)document.body.classList.add('tar');
function $(i){return document.getElementById(i)}
function durum(t){$('durum').textContent=t}
function ipucu(t){var d=document.createElement('div');d.className='ipucu';d.textContent=t;document.body.appendChild(d);setTimeout(function(){d.style.opacity=0},1600);setTimeout(function(){d.remove()},2000)}
function mobilMi(){return A.cihaz==='mobil'}
function cihazUygula(){document.body.classList.toggle('mobil',mobilMi());$('kipD').style.display=mobilMi()?'':'none';$('kipD').textContent=A.kip==='pad'?'Touchpad':'Dokunmatik';imlecEl.style.display=(mobilMi()&&A.kip==='pad')?'block':'none';yerlestir()}
// ---- protokol ----
function cer(t,s){var b=typeof s==='string'||s===undefined?new TextEncoder().encode(s||''):s;var a=new Uint8Array(5+b.length);a[0]=t.charCodeAt(0);a[1]=b.length>>>24;a[2]=(b.length>>>16)&255;a[3]=(b.length>>>8)&255;a[4]=b.length&255;a.set(b,5);if(ws&&ws.readyState==1)ws.send(a)}
function genislik(){if(A.coz&&A.coz!=='oto')return +A.coz;var dpr=window.devicePixelRatio||1;return Math.round(Math.min(1920,Math.max(640,Math.max(screen.width,screen.height,alan.clientWidth)*Math.min(dpr,2))))}
function bagla(){if(ws){try{ws.onclose=null;ws.close()}catch(e){}}
ws=new WebSocket((location.protocol=='https:'?'wss://':'ws://')+location.host+'/panel/ws?hedef='+encodeURIComponent(HEDEF));ws.binaryType='arraybuffer';
ws.onopen=function(){var g=genislik();if(TAR)g=Math.min(g,1920);var h='istemci=web\nkip=akis\nkalite='+(A.kal||60)+'\nfps='+(A.fps||15)+'\nad=Web panel ('+(mobilMi()?'mobil':'PC')+')\ngenislik='+g;if(!TAR&&videoIste())h+='\ncodec=h264';
if(TAR){var r=alan.clientHeight/Math.max(1,alan.clientWidth);h+='\ngorunum='+g+'x'+Math.round(g*Math.max(0.4,Math.min(2.2,r)))}cer('H',h);durum('Kimlik doğrulanıyor…')};
ws.onclose=function(){durum('Bağlantı kapandı — 3 sn sonra yeniden');setTimeout(bagla,3000)};ws.onerror=function(){durum('Bağlantı hatası')};
ws.onmessage=function(ev){var g=new Uint8Array(ev.data),n=new Uint8Array(buf.length+g.length);n.set(buf);n.set(g,buf.length);buf=n;
while(buf.length>=5){var L=(buf[1]<<24|buf[2]<<16|buf[3]<<8|buf[4])>>>0;if(buf.length<5+L)break;var t=String.fromCharCode(buf[0]),v=buf.slice(5,5+L);buf=buf.slice(5+L);isle(t,v)}}}
var kareSay=0,kareZaman=Date.now(),fpsOlcum=0;
function isle(t,v){if(t=='V'){videoKare(v);return}var m=t=='J'||t=='K'?'':new TextDecoder().decode(v);if(t=='K')return;
if(t=='J'){cer('G');kareSay++;baytSay+=v.length;if(vidKullan)videoGizle();var u=URL.createObjectURL(new Blob([v],{type:'image/jpeg'}));img.onload=function(){if(eskiUrl)URL.revokeObjectURL(eskiUrl);eskiUrl=u;if(img.naturalWidth!==dogal.w||img.naturalHeight!==dogal.h){dogal.w=img.naturalWidth;dogal.h=img.naturalHeight;yerlestir()}};img.src=u;
sayacGoster()}
else if(t=='O'){bagliAd=(/ad=([^\n]*)/.exec(m)||[])[1]||HEDEF;durum('Bağlı: '+bagliAd);cer('S','masaustu');cer('F')}
else if(t=='N')durum('Reddedildi: '+m);else if(t=='M')durum(m);
else if(t=='R'){var a=m.split('\n');var ad=$('adres');if(ad&&document.activeElement!=ad)ad.value=a[0]||'';document.title=(a[1]||'Sunucu tarayıcısı')+' • Belle'}
else if(t=='D'){var d=m.split('\t');if(confirm('İndirme hazır: '+d[1]+'\nDrive\'a yüklensin mi?'))cer('d','drive '+d[0])}}
var bagliAd=HEDEF;
// ---- H.264 video (WebCodecs): PC uygulamasi codec=h264 isteyen panele video gonderir; Nokia ve sunucu tarayicisi JPEG ----
var dec=null,decKod='',vidCtx=null,vidKullan=false,anahtarBekle=true,vts=0,sonFIste=0,decHata=0,videoKapali=false,baytSay=0,bicim='JPEG';
function videoOk(){return typeof VideoDecoder!=='undefined'&&typeof EncodedVideoChunk!=='undefined'}
function videoIste(){return videoOk()&&!videoKapali&&(A.bic||'h264')!=='jpeg'}
function spsKod(d){for(var i=0;i+7<d.length;i++){if(d[i]===0&&d[i+1]===0&&d[i+2]===1&&(d[i+3]&31)===7){var h=function(x){return('0'+x.toString(16)).slice(-2)};return 'avc1.'+h(d[i+4])+h(d[i+5])+h(d[i+6])}}return null}
function fIste(){var t=Date.now();if(t-sonFIste>800){sonFIste=t;cer('F')}}
function videoGoster(){if(vidKullan)return;vidKullan=true;bicim='H.264';img.style.display='none';vid.style.display='block';gorEl=vid}
function videoGizle(){vidKullan=false;bicim='JPEG';vid.style.display='none';img.style.display='block';gorEl=img;if(dec){try{dec.close()}catch(e){}dec=null}decKod=''}
function jpegeGec(neden){videoKapali=true;ipucu(neden+' — JPEG kullanılıyor');videoGizle();bagla()}
function decKur(kod){if(dec){try{dec.close()}catch(e){}}
if(!vidCtx)vidCtx=vid.getContext('2d',{alpha:false,desynchronized:true});
dec=new VideoDecoder({output:function(f){var w=f.displayWidth,h=f.displayHeight;if(vid.width!==w||vid.height!==h){vid.width=w;vid.height=h}vidCtx.drawImage(f,0,0);f.close();if(dogal.w!==w||dogal.h!==h){dogal.w=w;dogal.h=h;yerlestir()}decHata=0},
error:function(e){dec=null;decKod='';anahtarBekle=true;decHata++;if(decHata>=3)jpegeGec('Video çözülemedi ('+(e&&e.message||e)+')');else fIste()}});
dec.configure({codec:kod,optimizeForLatency:true});decKod=kod}
function videoKare(v){cer('G');kareSay++;baytSay+=v.length;var key=(v[0]&1)===1,d=v.subarray(1);
if(key){var k=spsKod(d);if(k&&(k!==decKod||!dec||dec.state==='closed')){try{decKur(k)}catch(e){jpegeGec('Bu tarayıcı H.264 çözemiyor');return}}if(dec)anahtarBekle=false}
if(anahtarBekle||!dec||dec.state!=='configured'){fIste();sayacGoster();return}
videoGoster();
// cozucu geride kalirsa (yavas cihaz) bir sonraki anahtar kareye kadar beklemek yerine kuyrugu bosalt
if(dec.decodeQueueSize>8&&!key){anahtarBekle=true;fIste();return}
try{dec.decode(new EncodedVideoChunk({type:key?'key':'delta',timestamp:(vts+=16667),data:d}))}catch(e){anahtarBekle=true;fIste()}
sayacGoster()}
function sayacGoster(){var s=Date.now();if(s-kareZaman>1000){var sn=(s-kareZaman)/1000;fpsOlcum=Math.round(kareSay/sn);var kb=Math.round(baytSay*8/1000/sn);kareSay=0;baytSay=0;kareZaman=s;
durum(bagliAd+' • '+bicim+' • '+dogal.w+'×'+dogal.h+' • '+fpsOlcum+' fps • '+(kb>=1000?(kb/1000).toFixed(1)+' Mbit/s':kb+' kbit/s'))}}
// ---- yerlesim: goruntu alana sigar (genis ekran / dikey telefon) + yerel yakinlastirma ----
var taban={x:0,y:0,s:1};
function yerlestir(){if(!dogal.w)return;var W=alan.clientWidth,Hh=alan.clientHeight,s=Math.min(W/dogal.w,Hh/dogal.h);taban={s:s,x:(W-dogal.w*s)/2,y:(Hh-dogal.h*s)/2};img.style.width=vid.style.width=dogal.w*s+'px';img.style.height=vid.style.height=dogal.h*s+'px';uygulaYak()}
function uygulaYak(){var s=yak.s;var W=alan.clientWidth,Hh=alan.clientHeight,w=dogal.w*taban.s*s,h=dogal.h*taban.s*s;
if(s<=1.001){yak.s=1;yak.x=taban.x;yak.y=taban.y}else{yak.x=Math.min(0,Math.max(W-w,yak.x));yak.y=Math.min(0,Math.max(Hh-h,yak.y));if(w<W)yak.x=(W-w)/2;if(h<Hh)yak.y=(Hh-h)/2}
sahne.style.transform='translate('+yak.x+'px,'+yak.y+'px) scale('+s+')';imlecCiz()}
function yakinSifir(){yak.s=1;uygulaYak()}
window.addEventListener('resize',function(){yerlestir()});
// ekran noktasi -> uzak koordinat (0..10000)
function uzak(clientX,clientY){var r=gorEl.getBoundingClientRect();return{x:Math.round(Math.max(0,Math.min(1,(clientX-r.left)/r.width))*10000),y:Math.round(Math.max(0,Math.min(1,(clientY-r.top)/r.height))*10000)}}
function imlecCiz(){if(!dogal.w)return;imlecEl.style.left=(cx/10000*dogal.w*taban.s)+'px';imlecEl.style.top=(cy/10000*dogal.h*taban.s)+'px';imlecEl.style.transform='scale('+(1/yak.s)+')';imlecEl.style.transformOrigin='0 0'}
function imlecGit(x,y){cx=Math.max(0,Math.min(10000,x));cy=Math.max(0,Math.min(10000,y));imlecCiz();var t=Date.now();if(t-sonM>30){sonM=t;cer('I','M '+cx+' '+cy)}}
function tik(b,x,y){if(x===undefined){x=cx;y=cy}cer('I','C '+b+' '+x+' '+y)}
// ---- PC: fare ----
alan.addEventListener('mousemove',function(ev){if(mobilMi())return;var p=uzak(ev.clientX,ev.clientY);cx=p.x;cy=p.y;var t=Date.now();if(t-sonM<25)return;sonM=t;cer('I','M '+p.x+' '+p.y)});
alan.addEventListener('mousedown',function(ev){if(mobilMi())return;ev.preventDefault();alan.focus();var p=uzak(ev.clientX,ev.clientY);cer('I','D '+(ev.button==2?'R':ev.button==1?'M':'L')+' '+p.x+' '+p.y)});
alan.addEventListener('mouseup',function(ev){if(mobilMi())return;ev.preventDefault();var p=uzak(ev.clientX,ev.clientY);cer('I','U '+(ev.button==2?'R':ev.button==1?'M':'L')+' '+p.x+' '+p.y)});
alan.addEventListener('contextmenu',function(ev){ev.preventDefault()});
alan.addEventListener('wheel',function(ev){ev.preventDefault();if(ev.ctrlKey&&mobilMi()===false&&false)return;var n=Math.max(1,Math.min(5,Math.round(Math.abs(ev.deltaY||ev.deltaX)/60)));if(Math.abs(ev.deltaX)>Math.abs(ev.deltaY))cer('I','X '+(ev.deltaX>0?n:-n));else cer('I','W '+(ev.deltaY>0?-n:n))},{passive:false});
alan.tabIndex=0;
// ---- mobil: dokunma ----
var d0=null,iki=null,uzunZ=null,suruklendi=false,surukleBasildi=false,sonDokun=0;
function dokunBasla(ev){if(!mobilMi())return;ev.preventDefault();var T=ev.touches;
if(T.length===2){clearTimeout(uzunZ);d0=null;if(surukleBasildi){cer('I','U L '+cx+' '+cy);surukleBasildi=false}
var a=T[0],b=T[1];iki={d:Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY),mx:(a.clientX+b.clientX)/2,my:(a.clientY+b.clientY)/2,s:yak.s,x:yak.x,y:yak.y,kaydirY:(a.clientY+b.clientY)/2,tekerlek:false,zaman:Date.now()};return}
if(T.length!==1)return;var t=T[0];d0={x:t.clientX,y:t.clientY,lx:t.clientX,ly:t.clientY,z:Date.now(),cx:cx,cy:cy};suruklendi=false;
var ciftDokun=Date.now()-sonDokun<300;
if(A.kip!=='pad'){var p=uzak(t.clientX,t.clientY);imlecGit(p.x,p.y)}
// uzun bas: sag tik (dokunmatik kipte orada; touchpad'de imlecte). Touchpad'de cift dokunup basili tut: surukle
if(A.kip==='pad'&&ciftDokun){surukleBasildi=true;cer('I','D L '+cx+' '+cy);return}
uzunZ=setTimeout(function(){if(!suruklendi&&d0){tik('R');ipucu('Sağ tık');if(navigator.vibrate)navigator.vibrate(30);d0=null}},550)}
function dokunHareket(ev){if(!mobilMi())return;ev.preventDefault();var T=ev.touches;
if(T.length===2&&iki){var a=T[0],b=T[1],d=Math.hypot(a.clientX-b.clientX,a.clientY-b.clientY),mx=(a.clientX+b.clientX)/2,my=(a.clientY+b.clientY)/2;
var oran=d/iki.d;
if(!iki.tekerlek&&Math.abs(oran-1)>0.08){var r=alan.getBoundingClientRect();var ns=Math.max(1,Math.min(6,iki.s*oran));var px=iki.mx-r.left,py=iki.my-r.top;yak.x=px-(px-iki.x)*(ns/iki.s)+(mx-iki.mx);yak.y=py-(py-iki.y)*(ns/iki.s)+(my-iki.my);yak.s=ns;uygulaYak()}
else if(yak.s>1.01&&Math.abs(oran-1)<=0.08&&!iki.tekerlek){yak.x=iki.x+(mx-iki.mx);yak.y=iki.y+(my-iki.my);uygulaYak()}
else if(Math.abs(oran-1)<=0.08){var dy=my-iki.kaydirY;if(Math.abs(dy)>28){iki.tekerlek=true;cer('I','W '+(dy>0?1:-1));iki.kaydirY=my}}
return}
if(T.length!==1||!d0)return;var t=T[0];var dx=t.clientX-d0.lx,dy=t.clientY-d0.ly;
if(!suruklendi&&Math.hypot(t.clientX-d0.x,t.clientY-d0.y)>10){suruklendi=true;clearTimeout(uzunZ);
if(A.kip!=='pad'&&!surukleBasildi){surukleBasildi=true;var p0=uzak(d0.x,d0.y);cer('I','D L '+p0.x+' '+p0.y)}}
if(!suruklendi)return;d0.lx=t.clientX;d0.ly=t.clientY;
if(A.kip==='pad'){var r=gorEl.getBoundingClientRect();var hiz=1.6;imlecGit(cx+dx*hiz*10000/r.width,cy+dy*hiz*10000/r.height)}
else{var p=uzak(t.clientX,t.clientY);imlecGit(p.x,p.y)}}
function dokunBitir(ev){if(!mobilMi())return;ev.preventDefault();clearTimeout(uzunZ);
if(iki&&ev.touches.length===0){var kisa=Date.now()-iki.zaman<250&&!iki.tekerlek&&Math.abs(yak.s-iki.s)<0.05;iki=null;if(kisa){tik('R');ipucu('Sağ tık (iki parmak)')}return}
if(iki)return;
if(surukleBasildi){cer('I','U L '+cx+' '+cy);surukleBasildi=false;d0=null;return}
if(d0&&!suruklendi){sonDokun=Date.now();if(A.kip==='pad')tik('L');else{var p=uzak(d0.x,d0.y);tik('L',p.x,p.y)}
if(A.kip==='pad'&&false)klavye()}
d0=null}
alan.addEventListener('touchstart',dokunBasla,{passive:false});alan.addEventListener('touchmove',dokunHareket,{passive:false});alan.addEventListener('touchend',dokunBitir,{passive:false});alan.addEventListener('touchcancel',dokunBitir,{passive:false});
// ---- klavye ----
var OZEL={Enter:'enter',Backspace:'backspace',Tab:'tab',Escape:'esc',Delete:'delete',ArrowUp:'up',ArrowDown:'down',ArrowLeft:'left',ArrowRight:'right',Home:'home',End:'end',PageUp:'pageup',PageDown:'pagedown',Insert:'insert',F1:'f1',F2:'f2',F3:'f3',F4:'f4',F5:'f5',F6:'f6',F7:'f7',F8:'f8',F9:'f9',F10:'f10',F11:'f11',F12:'f12'};
function modOnek(){var s='';['ctrl','alt','shift','win'].forEach(function(k){if(modlar[k])s+=k+'+'});return s}
function modTemizle(){modlar={};['Ctrl','Alt','Shift','Win'].forEach(function(k){$('m'+k).classList.remove('ac')})}
function mod(k){modlar[k]=!modlar[k];$('m'+k.charAt(0).toUpperCase()+k.slice(1)).classList.toggle('ac',!!modlar[k])}
function tus(k){var o=modOnek();cer('I','K '+(o&&k.indexOf('+')<0?o:'')+k);modTemizle()}
// PC klavyesi: alan odakliyken her sey dogrudan
document.addEventListener('keydown',function(ev){if(document.activeElement===$('adres')||document.activeElement===gizli)return;if($('ayar').style.display==='flex')return;
var k=OZEL[ev.key];var md=(ev.ctrlKey?'ctrl+':'')+(ev.altKey?'alt+':'')+(ev.metaKey?'win+':'');
if(k){ev.preventDefault();cer('I','K '+md+(ev.shiftKey&&md?'shift+':'')+k)}else if(md&&ev.key.length==1){ev.preventDefault();cer('I','K '+md+ev.key.toLowerCase())}else if(ev.key.length==1){ev.preventDefault();cer('Y',ev.key)}});
// Mobil: gizli kutu telefonun klavyesini acar; yazilanlar aninda gider (otomatik duzeltme/tahmin kapali)
function klavye(){gizli.value='  ';gizli.focus({preventScroll:true});setTimeout(function(){gizli.setSelectionRange(2,2)},0)}
gizli.addEventListener('beforeinput',function(ev){var t=ev.inputType;
if(t==='insertText'||t==='insertCompositionText'&&false){ev.preventDefault();var o=modOnek();if(o&&ev.data&&ev.data.length===1){cer('I','K '+o+ev.data.toLowerCase());modTemizle()}else cer('Y',ev.data||'')}
else if(t==='insertLineBreak'||t==='insertParagraph'){ev.preventDefault();tus('enter')}
else if(t==='deleteContentBackward'){ev.preventDefault();tus('backspace')}
else if(t==='deleteContentForward'){ev.preventDefault();tus('delete')}});
// beforeinput desteklemeyen / IME (kompozisyon) klavyeler: degisikligi farktan bul
gizli.addEventListener('input',function(){var v=gizli.value;if(v.length>2){cer('Y',v.slice(2))}else if(v.length<2){for(var i=v.length;i<2;i++)tus('backspace')}gizli.value='  ';gizli.setSelectionRange(2,2)});
gizli.addEventListener('keydown',function(ev){var k=OZEL[ev.key];if(k&&k!=='backspace'){ev.preventDefault();tus(k)}});
// ---- tarayici ----
function git(){var a=$('adres');cer('U',a.value);a.blur()}function kom(k){cer('B',k)}
function tam(){var e=document.documentElement;if(document.fullscreenElement)document.exitFullscreen();else (e.requestFullscreen||e.webkitRequestFullscreen).call(e);setTimeout(yerlestir,300)}
// Imlec (touchpad) kipi acilinca telefonun klavyesi de acilir (dokunma aninda: tarayicilar ancak kullanici hareketiyle izin verir)
function kipDegis(){A.kip=A.kip==='pad'?'dokun':'pad';kaydet();cihazUygula();ipucu(A.kip==='pad'?'İmleç kipi: parmakla imleci kaydırın, dokunun = tık, iki kez dokunup basılı tutun = sürükle':'Dokunmatik: dokunduğunuz yere tıklanır, basılı tutun = sağ tık');if(A.kip==='pad')klavye();else gizli.blur()}
function klavyeIpucu(){ipucu('Yazmak için ⌨ düğmesi telefonun klavyesini açar')}
// ---- ayarlar ----
function ayarAc(){$('aBic').value=A.bic||(videoOk()?'h264':'jpeg');$('aCoz').value=A.coz||'oto';$('aFps').value=String(A.fps||15);$('aKal').value=String(A.kal||60);$('aCihaz').value=A.cihaz||'pc';$('aKip').value=A.kip||'dokun';$('ayar').style.display='flex'}
function ayarKapat(uygula){$('ayar').style.display='none';if(!uygula)return;var eski=[A.coz,A.fps,A.kal,A.bic].join();A.bic=$('aBic').value;videoKapali=false;
A.coz=$('aCoz').value;A.fps=+$('aFps').value;A.kal=+$('aKal').value;A.cihaz=$('aCihaz').value;A.kip=$('aKip').value;kaydet();cihazUygula();
if(eski!==[A.coz,A.fps,A.kal,A.bic].join()){durum('Yeni ayarlarla yeniden bağlanılıyor…');bagla()}}
function cihazSec(c){A.cihaz=c;if(!A.kip)A.kip=c==='mobil'?'pad':'dokun';if(!A.fps)A.fps=c==='mobil'?12:20;if(!A.kal)A.kal=c==='mobil'?55:70;kaydet();$('secim').style.display='none';cihazUygula();bagla()}
setInterval(function(){cer('P',''+Math.floor(Date.now()/1000))},10000);
if(!A.cihaz){$('secim').style.display='flex';var dokunmatik=('ontouchstart' in window)||navigator.maxTouchPoints>0}else{cihazUygula();bagla()}
`;

module.exports = { sayfa };
