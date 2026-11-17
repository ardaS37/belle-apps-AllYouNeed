// Web panelinde telefon uygulamalarinin karsiliklari (ayni ozellikler, ayni sunucu uclari):
//   /panel/whatsapp   WhatsBelle (eski WhatsBelle): sohbet listesi, mesajlar, gonderme, foto/video/ses/dosya, kisi arama, alintilar
//   /panel/ai         ApiLauncher (ApiLauncher): GPT / Claude / Gemini / Grok sekmeleri, model secimi, sistem istemi,
//                     fotograf gonderme, resim cizme (resim modeli secimi), konusma gecmisi, anahtarlari sunucuya kaydetme
//   /panel/youtube    BelleTube: ara, akis (abonelikler), abonelikler, kanal, oynatma listeleri, begenilenler, yorumlar, MP3
module.exports = function (o) {
    const { router, sayfa } = o;
    const wa = require("./WhatsappClient.js");

    const ORTAK = `function e(s){return (''+(s==null?'':s)).replace(/[&<>"']/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]})}
function j(u,o){return fetch(u,o).then(function(r){return r.json().catch(function(){return {error:'HTTP '+r.status}}).then(function(d){if(!r.ok&&!d.error)d.error='HTTP '+r.status;return d})})}
function q(s){return e((''+(s==null?'':s)).replace(/['"\\\\]/g,''))}
function ls(k,v){try{if(v===undefined)return localStorage.getItem(k);localStorage.setItem(k,v)}catch(x){return null}}`;

    // =====================================================================================
    // WhatsBelle
    // =====================================================================================
    router.get("/panel/api/wa/hesaplar", (req, res) => res.json({ hesaplar: wa.hazirHesaplar ? wa.hazirHesaplar() : [] }));

    router.get("/panel/whatsapp", (req, res) => {
        res.type("html").send(sayfa("WhatsBelle", `<style>
.wa{display:flex;height:calc(100vh - 90px);min-height:420px;background:var(--kart);border:1px solid var(--cizgi);border-radius:14px;overflow:hidden}
.wa .sol{width:340px;border-right:1px solid var(--cizgi);display:flex;flex-direction:column}.wa .sag{flex:1;display:flex;flex-direction:column;min-width:0}
.wa .ust{padding:10px 12px;border-bottom:1px solid var(--cizgi);display:flex;gap:8px;align-items:center}
.wa .liste{overflow:auto;flex:1}.wa .sh{display:flex;gap:10px;padding:10px 12px;cursor:pointer;border-bottom:1px solid var(--cizgi);align-items:center}
.wa .sh:hover,.wa .sh.sec{background:var(--bg)}.wa .av{width:42px;height:42px;border-radius:50%;background:#25D36633;flex:none;object-fit:cover;display:flex;align-items:center;justify-content:center;font-weight:600}
.wa .sh .ad{font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.wa .sh .son{color:var(--ikinci);font-size:13px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.wa .okunmamis{background:#25D366;color:#fff;border-radius:12px;font-size:12px;padding:1px 7px;margin-left:auto}
.wa .mesajlar{flex:1;overflow:auto;padding:14px;background:var(--bg)}.wa .b{max-width:72%;margin:4px 0;padding:7px 10px;border-radius:10px;background:var(--kart);border:1px solid var(--cizgi);white-space:pre-wrap;word-wrap:break-word;clear:both}
.wa .b.ben{float:right;background:#d9fdd3;border-color:#c5ecbe;color:#111}@media(prefers-color-scheme:dark){.wa .b.ben{background:#005c4b;border-color:#005c4b;color:#e9edef}}
.wa .b .z{font-size:11px;color:var(--ikinci);text-align:right;margin-top:2px}.wa .b.ben .z{color:inherit;opacity:.7}.wa .b img{max-width:100%;border-radius:8px;display:block;cursor:zoom-in}
.wa .b .k{font-size:12px;font-weight:600;color:#1f8f5f}.wa .alinti{border-left:3px solid #25D366;padding:3px 7px;margin-bottom:4px;font-size:13px;background:#0000000d;border-radius:4px}
.wa .gun{text-align:center;clear:both;margin:10px 0}.wa .gun span{background:var(--kart);border:1px solid var(--cizgi);border-radius:8px;padding:2px 10px;font-size:12px;color:var(--ikinci)}
.wa .yaz{display:flex;gap:8px;padding:10px;border-top:1px solid var(--cizgi);align-items:flex-end}.wa .yaz textarea{resize:none;max-height:140px}
.wa .bos{margin:auto;color:var(--ikinci);text-align:center;padding:20px}
@media(max-width:760px){.wa .sol{width:100%}.wa.acik .sol{display:none}.wa:not(.acik) .sag{display:none}}
</style>
<div class="wa" id="wa"><div class="sol"><div class="ust"><select id="hesap" style="flex:1"></select><button class="ikinci" title="Yenile" onclick="sohbetler(true)">⟳</button></div>
<div class="ust"><input id="ara" placeholder="Kişi ara / yeni sohbet" oninput="araZaman()"></div><div class="liste" id="liste"><div class="bos">Yükleniyor…</div></div></div>
<div class="sag"><div class="ust"><button class="ikinci" onclick="geri()" id="geriD">‹</button><span class="av" id="sav"></span><div style="min-width:0"><b id="sad">Sohbet seçin</b><div class="alt" id="salt"></div></div></div>
<div class="mesajlar" id="mesajlar"><div class="bos">Soldan bir sohbet seçin.<br><br>Telefonda WhatsBelle ile aynı hesap ve aynı sohbetler.</div></div>
<div class="yaz"><label class="btn ikinci" title="Foto, video, ses ya da dosya gönder">📎<input type="file" id="dosya" hidden onchange="dosyaGonder(this)"></label>
<textarea id="metin" rows="1" placeholder="Mesaj yazın (Enter: gönder, Shift+Enter: satır)"></textarea><button onclick="gonder()">Gönder</button></div></div></div>
<p class="alt">Hesap bağlı değilse <a href="/login">QR ile bağlayın</a> • <a href="/whatsapp">eski WhatsApp sayfası</a></p>`, `<script>${ORTAK}
var ben='',acik=null,acikAd='',sonImza='',aramaZ=null,sohbetVeri=[],boyut=30,dahaVar=false;
function av(id,ad){return '<img class="av" src="/api/avatar/'+ben+'/'+encodeURIComponent(id)+'.png" onerror="this.outerHTML=\\'<span class=av>'+e((ad||'?').charAt(0).toUpperCase())+'</span>\\'">'}
function hesaplar(){j('/panel/api/wa/hesaplar').then(function(d){var h=d.hesaplar||[],s=document.getElementById('hesap');
if(!h.length){s.innerHTML='<option>Bağlı hesap yok</option>';document.getElementById('liste').innerHTML='<div class="bos">WhatsApp hesabı bağlı değil.<br><a href="/login">QR ile bağla</a></div>';return}
s.innerHTML=h.map(function(x){return '<option value="'+x.id+'">'+e(x.ad||'')+' +'+x.id+'</option>'}).join('');var k=ls('wa_hesap');if(k&&h.some(function(x){return x.id==k}))s.value=k;ben=s.value;sohbetler()})}
document.getElementById('hesap').onchange=function(){ben=this.value;ls('wa_hesap',ben);acik=null;sohbetler()};
function zaman(s){if(!s)return '';var d=new Date((''+s).replace(' ','T'));if(isNaN(d))return s;var b=new Date();return d.toDateString()==b.toDateString()?d.toTimeString().slice(0,5):d.toLocaleDateString('tr-TR')}
function sohbetler(yenile){if(!ben)return;j('/api/chats/'+ben+'@c.us?page_size='+boyut+'&page=0').then(function(d){dahaVar=!!d.more;if(d.error){document.getElementById('liste').innerHTML='<div class="bos hata">'+e(d.error)+'</div>';return}
sohbetVeri=d.chats||[];if(!document.getElementById('ara').value)listeCiz(sohbetVeri)})}
function listeCiz(l){document.getElementById('liste').innerHTML=l.map(function(c){var id=c.sender||c._id,ad=c.senderName||c.name||id.split('@')[0];
return '<div class="sh'+(id==acik?' sec':'')+'" onclick="ac(\\''+q(id)+'\\',\\''+q(ad)+'\\')">'+av(id,ad)+'<div style="min-width:0;flex:1"><div class="ad">'+e(ad)+'</div><div class="son">'+e(c.message||'')+'</div></div><div style="text-align:right"><div class="alt">'+zaman(c.createdAt)+'</div>'+(c.unread?'<span class="okunmamis">'+c.unread+'</span>':'')+'</div></div>'}).join('')+(dahaVar&&!document.getElementById('ara').value?'<div class="bos"><button class="ikinci" onclick="boyut+=30;sohbetler()">Daha eski sohbetler</button></div>':'')||'<div class="bos">Sohbet yok</div>'}
function araZaman(){clearTimeout(aramaZ);aramaZ=setTimeout(ara,350)}
function ara(){var q=document.getElementById('ara').value.trim();if(!q){listeCiz(sohbetVeri);return}
var yerel=sohbetVeri.filter(function(c){return (c.senderName||'').toLocaleLowerCase('tr').indexOf(q.toLocaleLowerCase('tr'))>=0});
j('/api/contacts/'+ben+'?search_term='+encodeURIComponent(q)+'&page_size=30&page=0').then(function(d){var k=(d.contacts||[]).map(function(x){return {sender:x.id,senderName:x.name,message:'Kişi'}});
var g=/^\\+?\\d{10,15}$/.test(q.replace(/\\s/g,''))?[{sender:q.replace(/\\D/g,'')+'@c.us',senderName:'+'+q.replace(/\\D/g,''),message:'Bu numaraya yaz'}]:[];listeCiz(yerel.concat(k,g))})}
function ac(id,ad){acik=id;acikAd=ad;sonImza='';document.getElementById('wa').classList.add('acik');document.getElementById('sad').textContent=ad;document.getElementById('salt').textContent=id.indexOf('@g.us')>0?'Grup':'+'+id.split('@')[0];
document.getElementById('sav').outerHTML='<span id="sav">'+av(id,ad)+'</span>';document.getElementById('mesajlar').innerHTML='<div class="bos">Yükleniyor…</div>';mesajlar();listeCiz(sohbetVeri)}
function geri(){document.getElementById('wa').classList.remove('acik');acik=null}
function medya(m){var t=m.chatType;if(t=='image')return '<img loading="lazy" src="/api/mediafile/'+m._id+'.jpg" onclick="window.open(this.src)">';
if(t=='audio'||t=='ptt')return '<audio controls preload="none" src="/api/mediafile/'+m._id+'.mp3" style="max-width:260px"></audio>';
if(t=='video')return '<a class="btn ikinci" href="/api/mediafile/'+m._id+'.3gp" download>🎬 Videoyu indir</a>';return ''}
function mesajlar(){if(!acik)return;var id=acik;j('/api/messages/'+ben+'@c.us/'+encodeURIComponent(id)+'?limit=60').then(function(d){if(id!=acik)return;var l=(d.messages||[]).slice().reverse();
var imza=l.length+':'+(l.length?l[l.length-1]._id+l[l.length-1].status:'');if(imza==sonImza)return;sonImza=imza;var kut=document.getElementById('mesajlar');var altta=kut.scrollHeight-kut.scrollTop-kut.clientHeight<80;
var h='',gun='';l.forEach(function(m){var g=(m.createdAt||'').slice(0,10);if(g&&g!=gun){gun=g;h+='<div class="gun"><span>'+e(new Date(g).toLocaleDateString('tr-TR',{day:'numeric',month:'long',year:'numeric'}))+'</span></div>'}
var mine=m.sender==ben+'@c.us',md=medya(m),yazi=m.message||'';if(md&&/ received$/.test(yazi))yazi='';
h+='<div class="b'+(mine?' ben':'')+'">'+(!mine&&id.indexOf('@g.us')>0&&m.senderName?'<div class="k">'+e(m.senderName)+'</div>':'')+(m.quote&&m.quote.text?'<div class="alinti"><b>'+e(m.quote.name||'')+'</b><br>'+e(m.quote.text)+'</div>':'')+md+(yazi?'<div>'+e(yazi)+'</div>':'')
+'<div class="z">'+(m.createdAt||'').slice(11,16)+(mine?' '+(m.status>=3?'<span style="color:#53bdeb">✓✓</span>':m.status>=2?'✓✓':'✓'):'')+'</div></div>'});
kut.innerHTML=h||'<div class="bos">Mesaj yok</div>';if(altta||!kut.dataset.ilk){kut.scrollTop=kut.scrollHeight;kut.dataset.ilk=1}})}
function gonder(){var t=document.getElementById('metin');var s=t.value.trim();if(!s||!acik)return;t.value='';var kut=document.getElementById('mesajlar');kut.insertAdjacentHTML('beforeend','<div class="b ben" style="opacity:.6">'+e(s)+'<div class="z">gönderiliyor…</div></div>');kut.scrollTop=kut.scrollHeight;
j('/api/messages',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({sender:ben,receiver:acik,message:s})}).then(function(d){if(d.error||(d.statusCode&&d.statusCode!='000'))alert('Gönderilemedi: '+(d.error||d.statusDesc));sonImza='';setTimeout(mesajlar,800);setTimeout(sohbetler,1500)})}
function dosyaGonder(inp){var f=inp.files[0];inp.value='';if(!f||!acik)return;if(f.size>16*1048576){alert('En fazla 16 MB');return}var fd=new FormData();fd.append('media',f);fd.append('sender',ben);fd.append('receiver',acik);
var kut=document.getElementById('mesajlar');kut.insertAdjacentHTML('beforeend','<div class="b ben" style="opacity:.6">📎 '+e(f.name)+'<div class="z">yükleniyor…</div></div>');kut.scrollTop=kut.scrollHeight;
j('/api/upload',{method:'POST',body:fd}).then(function(d){if(d.statusCode&&d.statusCode!='000')alert(d.statusDesc||'Gönderilemedi');sonImza='';setTimeout(mesajlar,1500)})}
document.getElementById('metin').addEventListener('keydown',function(ev){if(ev.key=='Enter'&&!ev.shiftKey){ev.preventDefault();gonder()}});
hesaplar();setInterval(function(){if(!document.hidden)mesajlar()},4000);setInterval(function(){if(!document.hidden&&!document.getElementById('ara').value)sohbetler()},20000);</script>`));
    });

    // =====================================================================================
    // ApiLauncher (ApiLauncher)
    // =====================================================================================
    router.get("/panel/ai", (req, res) => {
        res.type("html").send(sayfa("ApiLauncher", `<style>
.ai .sekmeler{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:10px}.ai .sekmeler button{background:var(--kart);color:var(--yazi);border:1px solid var(--cizgi)}.ai .sekmeler button.sec{background:var(--vurgu);color:#fff;border-color:var(--vurgu)}
.ai .duzen{display:flex;gap:12px}.ai .gecmis{width:240px;flex:none}.ai .gecmis .g{padding:8px 10px;border-radius:10px;cursor:pointer;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.ai .gecmis .g:hover,.ai .gecmis .g.sec{background:var(--kart)}
.ai .sohbet{flex:1;min-width:0;display:flex;flex-direction:column;height:calc(100vh - 150px);min-height:420px}.ai #log{flex:1;overflow:auto;padding:4px}
.ai .b{margin:8px 0;padding:10px 12px;border-radius:14px;background:var(--kart);border:1px solid var(--cizgi);max-width:88%;word-wrap:break-word}.ai .b.ben{margin-left:auto;background:var(--vurgu);color:#fff;border-color:var(--vurgu)}
.ai .b img{max-width:100%;max-height:420px;border-radius:10px;display:block;margin:4px 0}.ai .b .bilgi{font-size:12px;color:var(--ikinci);margin-top:4px}.ai .b.ben .bilgi{color:#ffffffb0}
.ai .b pre{background:#0000001a;border:0;max-height:none}.ai .b code{background:#0000001a;border-radius:4px;padding:0 3px}.ai .ret{border-color:var(--tehlike)}
.ai .yaz{display:flex;gap:8px;align-items:flex-end;margin-top:8px}.ai .yaz textarea{resize:none;max-height:160px}.ai .ek{display:flex;gap:8px;align-items:center;margin-top:6px;flex-wrap:wrap}.ai .ek img{height:56px;border-radius:8px}
@media(max-width:760px){.ai .gecmis{display:none}}
</style><div class="ai">
<div class="sekmeler" id="sekmeler"></div>
<div id="sohbetSayfa"><div class="duzen"><div class="gecmis"><button style="width:100%;margin-bottom:8px" onclick="yeni()">+ Yeni sohbet</button><div id="gecmis"></div></div>
<div class="sohbet"><div class="satir" style="margin-bottom:6px"><span class="alt" id="modelBilgi"></span><button class="ikinci" onclick="modelSec(false)">Model</button><button class="ikinci" id="cizModelD" onclick="modelSec(true)">Resim modeli</button></div>
<div id="log"></div>
<div class="ek" id="ekler"></div>
<div class="yaz"><label class="btn ikinci" title="Fotoğraf ekle">📷<input type="file" accept="image/*" id="foto" hidden onchange="fotoEkle(this)"></label>
<textarea id="t" rows="2" placeholder="Mesaj yazın (Enter: gönder, Shift+Enter: satır)"></textarea><button onclick="gonder()">Gönder</button><button class="ikinci" id="cizD" title="Yazdığınızı resim olarak çizdir" onclick="ciz()">🎨 Çiz</button></div></div></div></div>
<div id="ayarSayfa" hidden><div class="kart"><b>Sistem istemi</b> <span class="alt">(dört modele de gider; bu tarayıcıda saklanır)</span><br><br>
<textarea id="sistem" rows="5"></textarea><div class="satir" style="margin-top:8px"><button onclick="sistemKaydet()">Kaydet</button><button class="ikinci" onclick="document.getElementById('sistem').value=VARSAYILAN;sistemKaydet()">Varsayılan</button><span class="alt" id="sistemDurum"></span></div></div><br>
<div class="kart"><b>API anahtarları (sunucuda saklanır)</b><p class="alt">Telefondaki ApiLauncher "Sunucu üzerinden" çalışırken de bu anahtarları kullanır. Boş bırakılan alan değişmez; "-" yazarsanız silinir.</p><div id="anahtarlar"></div><br><button onclick="anahtarKaydet()">Anahtarları sunucuya kaydet</button> <span class="alt" id="anahtarDurum"></span></div></div>
<div id="secici" hidden style="position:fixed;inset:0;background:#0008;z-index:20" onclick="if(event.target==this)this.hidden=true"><div class="kart" style="max-width:520px;margin:8vh auto;max-height:80vh;overflow:auto"><b id="seciciBaslik"></b><input id="seciciAra" placeholder="Süz" style="margin:8px 0" oninput="seciciCiz()"><div id="seciciListe"></div></div></div>
</div>`, `<script>${ORTAK}
var SAG={openai:{ad:'GPT',model:'gpt-5',img:'gpt-image-1'},claude:{ad:'Claude',model:'claude-opus-5-5'},gemini:{ad:'Gemini',model:'gemini-flash-latest',img:'gemini-2.5-flash-image'},grok:{ad:'Grok',model:'grok-4',img:'grok-2-image'}};
var VARSAYILAN='Kısa ve net yanıt ver. Giriş cümlesi, tekrar ve gereksiz açıklama yapma; gerekiyorsa maddeler halinde yaz. Soruyu hangi dilde sorarsam o dilde yanıtla.';
var p=ls('ai_sekme')||'openai',kon=null,ekFoto=null,secList=[],secImg=false,mesgul=false;
function model(x){return ls('ai_model_'+(x||p))||SAG[x||p].model}function imgModel(x){return ls('ai_img_'+(x||p))||SAG[x||p].img||''}
function sistem(){var s=ls('ai_sistem');return s===null?VARSAYILAN:s}
function konular(){try{return JSON.parse(ls('ai_kon_'+p)||'[]')}catch(x){return []}}
function konKaydet(l){try{ls('ai_kon_'+p,JSON.stringify(l.slice(0,60)))}catch(x){l.forEach(function(k){k.m.forEach(function(m){delete m.img;delete m.ciz})});try{ls('ai_kon_'+p,JSON.stringify(l.slice(0,40)))}catch(y){}}}
function sekmeCiz(){document.getElementById('sekmeler').innerHTML=Object.keys(SAG).map(function(k){return '<button class="'+(k==p?'sec':'')+'" onclick="sekme(\\''+k+'\\')">'+SAG[k].ad+'</button>'}).join('')+'<button class="'+(p=='ayar'?'sec':'')+'" onclick="sekme(\\'ayar\\')">⚙ Ayarlar</button>';}
function sekme(k){p=k;ls('ai_sekme',k);sekmeCiz();var ay=k=='ayar';document.getElementById('ayarSayfa').hidden=!ay;document.getElementById('sohbetSayfa').hidden=ay;if(ay){ayarYukle();return}
kon=null;var l=konular();if(l.length)kon=l[0];gecmisCiz();ciz2();bilgi()}
function bilgi(){document.getElementById('modelBilgi').textContent=SAG[p].ad+' • '+model()+(SAG[p].img?' • resim: '+imgModel():'');var c=!!SAG[p].img;document.getElementById('cizD').hidden=!c;document.getElementById('cizModelD').hidden=!c}
function gecmisCiz(){document.getElementById('gecmis').innerHTML=konular().map(function(k,i){return '<div class="g'+(kon&&k.id==kon.id?' sec':'')+'" onclick="konAc('+i+')" title="'+e(k.b)+'">'+e(k.b)+'</div>'}).join('')||'<div class="alt">Geçmiş boş</div>'}
function konAc(i){kon=konular()[i];gecmisCiz();ciz2()}
function yeni(){kon=null;gecmisCiz();ciz2();document.getElementById('t').focus()}
function md(s){s=e(s);s=s.replace(/\`\`\`[a-z]*\\n?([\\s\\S]*?)\`\`\`/g,function(a,c){return '<pre>'+c+'</pre>'});s=s.replace(/\`([^\`\\n]+)\`/g,'<code>$1</code>').replace(/\\*\\*([^*\\n]+)\\*\\*/g,'<b>$1</b>');
return s.split(/(<pre>[\\s\\S]*?<\\/pre>)/).map(function(x){return x.indexOf('<pre>')==0?x:x.replace(/\\n/g,'<br>')}).join('')}
function ciz2(){var l=document.getElementById('log');if(!kon||!kon.m.length){l.innerHTML='<div class="alt" style="text-align:center;margin-top:20vh">'+SAG[p].ad+' ile yeni sohbet<br>'+e(model())+'</div>';return}
l.innerHTML=kon.m.map(function(m){var ben=m.role=='user';return '<div class="b'+(ben?' ben':'')+(m.ret?' ret':'')+'">'+(m.img?'<img src="data:image/jpeg;base64,'+m.img+'">':'')+(m.ciz?'<img src="data:image/'+(m.ext=='jpg'?'jpeg':'png')+';base64,'+m.ciz+'"><a class="btn ikinci" download="ApiLauncher.'+(m.ext||'png')+'" href="data:image/'+(m.ext=='jpg'?'jpeg':'png')+';base64,'+m.ciz+'">İndir</a>':'')+
(m.text?'<div>'+(ben?e(m.text).replace(/\\n/g,'<br>'):md(m.text))+'</div>':'')+(m.bilgi?'<div class="bilgi">'+e(m.bilgi)+'</div>':'')+'</div>'}).join('')+(mesgul?'<div class="b"><span class="alt">Yanıt bekleniyor…</span></div>':'');l.scrollTop=l.scrollHeight}
function konHazirla(baslik){if(!kon){kon={id:Date.now(),b:baslik.slice(0,60)||'Fotoğraf',m:[]}}}
function konSakla(){var l=konular().filter(function(k){return k.id!=kon.id});l.unshift(kon);konKaydet(l);gecmisCiz()}
function fotoEkle(inp){var f=inp.files[0];inp.value='';if(!f)return;var r=new FileReader();r.onload=function(){var im=new Image();im.onload=function(){var en=1024,o=Math.min(1,en/Math.max(im.width,im.height));var c=document.createElement('canvas');c.width=Math.round(im.width*o);c.height=Math.round(im.height*o);c.getContext('2d').drawImage(im,0,0,c.width,c.height);
ekFoto=c.toDataURL('image/jpeg',0.82).split(',')[1];document.getElementById('ekler').innerHTML='<img src="data:image/jpeg;base64,'+ekFoto+'"><span class="alt">'+c.width+'×'+c.height+' • '+Math.round(ekFoto.length*0.75/1024)+' KB</span><button class="ikinci" onclick="ekFoto=null;document.getElementById(\\'ekler\\').innerHTML=\\'\\'">Kaldır</button>'};im.src=r.result};r.readAsDataURL(f)}
function gonder(){if(mesgul||p=='ayar')return;var t=document.getElementById('t');var s=t.value.trim();if(!s&&!ekFoto)return;konHazirla(s);var m={role:'user',text:s};if(ekFoto)m.img=ekFoto;kon.m.push(m);t.value='';ekFoto=null;document.getElementById('ekler').innerHTML='';mesgul=true;ciz2();
var hist=kon.m.filter(function(x){return !x.ret&&(x.text||x.img)}).slice(-60).map(function(x){var o={role:x.role,text:x.text||''};if(x.img)o.img=x.img;return o});var pp=p,kk=kon;
j('/ai/chat',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({provider:pp,model:model(pp),system:sistem(),messages:hist})}).then(function(d){mesgul=false;
if(d.error)kk.m.push({role:'assistant',text:'Hata: '+d.error,ret:true});else if(d.refusal)kk.m.push({role:'assistant',text:d.refusal,ret:true,bilgi:d.model});else kk.m.push({role:'assistant',text:d.text||'',bilgi:(d.model||'')+' • '+((d.ms||0)/1000).toFixed(1)+' sn'});
kon=kk;konSakla();if(pp==p)ciz2()})}
function ciz(){if(mesgul)return;var t=document.getElementById('t');var s=t.value.trim();if(!s){alert('Çizilecek şeyi yazın');return}konHazirla('Resim: '+s);kon.m.push({role:'user',text:'🎨 '+s});t.value='';mesgul=true;ciz2();var pp=p,kk=kon;
j('/ai/draw',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({provider:pp,model:imgModel(pp),prompt:s})}).then(function(d){mesgul=false;
if(d.error)kk.m.push({role:'assistant',text:'Hata: '+d.error,ret:true});else kk.m.push({role:'assistant',ciz:d.b64,ext:d.ext,text:d.text||'',bilgi:(d.model||'')+' • '+((d.ms||0)/1000).toFixed(1)+' sn'});kon=kk;konSakla();if(pp==p)ciz2()})}
function modelSec(img){secImg=img;document.getElementById('secici').hidden=false;document.getElementById('seciciBaslik').textContent=SAG[p].ad+(img?' resim modeli':' modeli')+' • yükleniyor…';document.getElementById('seciciListe').innerHTML='';document.getElementById('seciciAra').value='';
j('/ai/models?provider='+p+(img?'&img=1':'')).then(function(d){secList=d.models||[];var bil=img?{openai:['gpt-image-1','gpt-image-1-mini','dall-e-3'],gemini:['gemini-2.5-flash-image','imagen-4.0-generate-001'],grok:['grok-2-image']}[p]||[]:[];bil.forEach(function(x){if(secList.indexOf(x)<0)secList.push(x)});
document.getElementById('seciciBaslik').textContent=SAG[p].ad+(img?' resim modeli':' modeli')+(d.error?' • '+d.error:' • '+secList.length+' model');seciciCiz()})}
function seciciCiz(){var q=document.getElementById('seciciAra').value.toLowerCase(),su=secImg?imgModel():model();document.getElementById('seciciListe').innerHTML=secList.filter(function(x){return x.toLowerCase().indexOf(q)>=0}).map(function(x){return '<div class="g" style="padding:8px;cursor:pointer;'+(x==su?'font-weight:700;color:var(--vurgu)':'')+'" onclick="modelAta(\\''+q(x)+'\\')">'+e(x)+'</div>'}).join('')+'<div class="satir" style="margin-top:8px"><input id="elleModel" placeholder="ya da model adını yazın"><button onclick="modelAta(document.getElementById(\\'elleModel\\').value.trim())">Kullan</button></div>'}
function modelAta(x){if(!x)return;ls((secImg?'ai_img_':'ai_model_')+p,x);document.getElementById('secici').hidden=true;bilgi();ciz2()}
function ayarYukle(){document.getElementById('sistem').value=sistem();j('/ai/keys').then(function(d){document.getElementById('anahtarlar').innerHTML=Object.keys(SAG).map(function(k){return '<div class="satir" style="margin:6px 0"><span style="flex:0 0 90px">'+SAG[k].ad+'</span><input type="password" id="k_'+k+'" placeholder="'+(d[k]?'Sunucuda kayıtlı (değiştirmek için yazın)':'Kayıtlı değil')+'" autocomplete="off"><span class="'+(d[k]?'ok':'alt')+'" style="flex:0 0 60px">'+(d[k]?'● var':'yok')+'</span></div>'}).join('')})}
function sistemKaydet(){ls('ai_sistem',document.getElementById('sistem').value);document.getElementById('sistemDurum').textContent='Kaydedildi';setTimeout(function(){document.getElementById('sistemDurum').textContent=''},2000)}
function anahtarKaydet(){var b={};Object.keys(SAG).forEach(function(k){var v=document.getElementById('k_'+k).value.trim();if(v)b[k]=v});j('/ai/keys',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(b)}).then(function(d){document.getElementById('anahtarDurum').textContent=d.error?'Hata: '+d.error:'Kaydedildi';ayarYukle()})}
document.getElementById('t').addEventListener('keydown',function(ev){if(ev.key=='Enter'&&!ev.shiftKey){ev.preventDefault();gonder()}});
sekmeCiz();sekme(p);</script>`));
    });

    // =====================================================================================
    // BelleTube
    // =====================================================================================
    router.get("/panel/youtube", (req, res) => {
        res.type("html").send(sayfa("BelleTube", `<style>.yt .sekmeler{display:flex;gap:6px;flex-wrap:wrap;margin:10px 0}.yt .sekmeler button{background:var(--kart);color:var(--yazi);border:1px solid var(--cizgi)}.yt .sekmeler button.sec{background:#FF0000;color:#fff;border-color:#FF0000}
.yt .v img{width:100%;aspect-ratio:16/9;object-fit:cover;border-radius:8px;background:#0002}.yt .v b{display:block;margin-top:6px;font-size:14px}.yt .kanal{display:flex;gap:10px;align-items:center}.yt .kanal img{width:44px;height:44px;border-radius:50%}
.yt .yorum{border-bottom:1px solid var(--cizgi);padding:8px 0;font-size:14px}</style><div class="yt">
<form class="satir" onsubmit="ara();return false"><input id="q" placeholder="YouTube'da ara"><button>Ara</button></form>
<div class="sekmeler" id="sekmeler"></div><div id="oynat"></div><div id="baslik"></div><div class="izgara" id="sonuc"></div><div id="dahaD" style="text-align:center;margin:12px" hidden><button class="ikinci" onclick="daha()">Daha fazla</button></div></div>`, `<script>${ORTAK}
var hesap=null,son=null,kalite=ls('yt_kalite')||'480';
var SEKME=[['ara','Ara'],['akis','Akış'],['abone','Abonelikler'],['liste','Oynatma listeleri'],['begen','Beğenilenler']];
function sekmeCiz(a){document.getElementById('sekmeler').innerHTML=SEKME.filter(function(s){return s[0]=='ara'||(hesap&&hesap.linked)||s[0]=='abone'}).map(function(s){return '<button class="'+(s[0]==a?'sec':'')+'" onclick="git(\\''+s[0]+'\\')">'+s[1]+'</button>'}).join('')+
'<select style="width:auto;margin-left:auto" onchange="kalite=this.value;ls(\\'yt_kalite\\',kalite)">'+['240','360','480','720'].map(function(k){return '<option'+(k==kalite?' selected':'')+'>'+k+'</option>'}).join('')+'</select>'+(hesap&&!hesap.linked?'<a class="btn ikinci" href="/yt/setup">Google hesabı bağla</a>':'')}
function vk(v){var s=[v.channel,v.length||v.duration,v.views,v.published].filter(Boolean).join(' • ');return '<a class="kart v" href="#" onclick="izle(\\''+v.id+'\\');return false"><img loading="lazy" src="/yt/thumb/'+v.id+'.jpg"><b>'+e(v.title)+'</b><span class="alt">'+e(s)+'</span></a>'}
function goster(d,baslik,f){document.getElementById('baslik').innerHTML=baslik||'';if(d.error){document.getElementById('sonuc').innerHTML='<div class="kart hata">'+e(d.error)+'</div>';return}
var h=(d.items||[]).map(f||vk).join('');document.getElementById('sonuc').insertAdjacentHTML('beforeend',h);if(!document.getElementById('sonuc').innerHTML)document.getElementById('sonuc').innerHTML='<div class="alt">Sonuç yok</div>';
document.getElementById('dahaD').hidden=!(d.more||d.next)}
function temizle(){document.getElementById('sonuc').innerHTML='<div class="alt">Yükleniyor…</div>';setTimeout(function(){},0)}
function yukle(u,baslik,f,ek){son={u:u,baslik:baslik,f:f,sayfa:0,next:''};if(!ek)document.getElementById('sonuc').innerHTML='';j(u).then(function(d){son.next=d.next||'';goster(d,baslik,f)})}
function daha(){if(!son)return;son.sayfa++;var u=son.u+(son.u.indexOf('?')<0?'?':'&')+(son.next?'pageToken='+encodeURIComponent(son.next):'page='+son.sayfa);j(u).then(function(d){son.next=d.next||'';goster(d,son.baslik,son.f)})}
function ara(){var q=document.getElementById('q').value.trim();if(!q)return;sekmeCiz('ara');yukle('/yt/search?q='+encodeURIComponent(q),'')}
function git(s){sekmeCiz(s);document.getElementById('dahaD').hidden=true;
if(s=='ara'){document.getElementById('sonuc').innerHTML='';document.getElementById('baslik').innerHTML='';document.getElementById('q').focus()}
else if(s=='akis')yukle('/yt/feed','<h2>Akış</h2>');
else if(s=='begen')yukle('/yt/liked','<h2>Beğenilenler</h2>');
else if(s=='abone')yukle('/yt/subs','<h2>Abonelikler</h2>',function(c){return '<a class="kart kanal" href="#" onclick="kanal(\\''+c.id+'\\');return false">'+(c.thumb?'<img src="'+e(c.thumb)+'">':'')+'<b>'+e(c.title)+'</b></a>'});
else if(s=='liste')yukle('/yt/playlists','<h2>Oynatma listeleri</h2>',function(l){return '<a class="kart kanal" href="#" onclick="liste(\\''+q(l.id)+'\\',\\''+q(l.title)+'\\');return false">'+(l.thumb?'<img src="'+e(l.thumb)+'" style="border-radius:8px">':'')+'<span><b>'+e(l.title)+'</b><br><span class="alt">'+l.count+' video</span></span></a>'})}
function kanal(id){document.getElementById('sonuc').innerHTML='';j('/yt/channel/'+id).then(function(d){var c=d.channel||{};son={u:'/yt/channel/'+id,f:null,sayfa:0,next:d.next||''};
goster(d,'<div class="kart kanal" style="margin:8px 0">'+(c.thumb?'<img src="'+e(c.thumb)+'">':'')+'<span><b>'+e(c.title||'Kanal')+'</b><br><span class="alt">'+e(c.subs||c.subscribers||'')+'</span></span><button class="ikinci" style="margin-left:auto" onclick="abone(\\''+q(id)+'\\',\\''+q(c.title||'')+'\\')">Abone ol</button></div>')});scrollTo(0,0)}
function abone(id,t){j('/yt/subs/add',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({id:id,title:t})}).then(function(d){alert(d.error?d.error:'Abonelere eklendi')})}
function liste(id,t){yukle('/yt/playlist/'+id,'<h2>'+e(t)+'</h2>')}
function izle(id){var o=document.getElementById('oynat');o.innerHTML='<div class="kart alt">Video sunucuda hazırlanıyor (ilk açılış biraz sürebilir)…</div>';scrollTo(0,0);
fetch('/yt/prepare/'+id+'?k='+kalite).then(function(r){return r.json()}).then(function(d){if(!d.ok){o.innerHTML='<div class="kart hata">'+e(d.error||'Hazırlanamadı')+'</div>';return}
o.innerHTML='<video controls autoplay style="width:100%;max-height:70vh;background:#000;border-radius:12px" src="/yt/stream/'+id+'.mp4?q='+kalite+'"></video><div id="vbilgi"></div><div class="satir" style="margin:8px 0;flex-wrap:wrap"><a class="btn ikinci" href="/yt/audio/'+id+'.mp3">Sesi indir (MP3)</a><a class="btn ikinci" href="/yt/stream/'+id+'.mp4?q='+kalite+'" download>Videoyu indir</a><a class="btn ikinci" target="_blank" href="https://www.youtube.com/watch?v='+id+'">YouTube\\'da aç</a><button class="ikinci" onclick="yorumlar(\\''+id+'\\')">Yorumlar</button></div><div id="yorum"></div>';
j('/yt/video/'+id).then(function(v){if(v.error)return;document.getElementById('vbilgi').innerHTML='<h2 style="margin:10px 0 4px">'+e(v.title||'')+'</h2><div class="alt">'+(v.channelId?'<a href="#" onclick="kanal(\\''+v.channelId+'\\');return false">'+e(v.channel||'')+'</a>':e(v.channel||''))+' • '+e([v.views,v.published,v.likes?v.likes+' beğeni':''].filter(Boolean).join(' • '))+'</div>'})})}
function yorumlar(id){document.getElementById('yorum').innerHTML='<div class="alt">Yükleniyor…</div>';j('/yt/comments/'+id).then(function(d){document.getElementById('yorum').innerHTML='<div class="kart">'+((d.items||d.comments||[]).map(function(c){return '<div class="yorum"><b>'+e(c.author||'')+'</b> <span class="alt">'+e(c.published||c.time||'')+'</span><br>'+e(c.text||'')+'</div>'}).join('')||e(d.error||'Yorum yok'))+'</div>'})}
j('/yt/auth/status').then(function(d){hesap=d.error?null:d;sekmeCiz('ara');if(hesap&&hesap.linked)git('akis')});sekmeCiz('ara');</script>`));
    });
};
