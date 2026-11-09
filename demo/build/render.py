import json,math,pathlib,subprocess,re,functools
from PIL import Image,ImageDraw,ImageFont
P=pathlib.Path(__file__).parent;LIVE=P.parent/'live'
W,H=1920,1080;FPS=30;LEAD=0.35;TAIL=0.45
FD='/workspace/hackathons/near/video/v2/fonts/'
@functools.lru_cache(None)
def F(size,w='Regular',mono=False):
  f=ImageFont.truetype(FD+('Mono.ttf' if mono else 'Inter.ttf'),size)
  if not mono:f.set_variation_by_name(w)
  return f
BG=(7,11,17);CARD=(14,21,30);LINE=(34,48,64);WHITE=(238,242,246);MINT=(94,242,176);CYAN=(94,214,242);AMBER=(242,199,94);RED=(255,138,138);MUTED=(138,150,163)
sc=json.loads((P/'script_timed.json').read_text())
run=json.loads((LIVE/'run.json').read_text());T0=run['events'][0][0]
frames=json.loads((LIVE/'frames.json').read_text());ftimes=[f[1]-T0 for f in frames]
# timeline
t=0
for s in sc:
  need=LEAD+s['vd']+TAIL
  if s['kind']=='live':
    s['clip']=s['b']-s['a'];s['dur']=max(need,s['clip'])
    if s.get('rt'):s['lead']=0.15
  else:s['dur']=need+(0.6 if s['id'] in('S1','C1') else 0.2)
  s.setdefault('lead',LEAD);s['start']=t;t+=s['dur']
TOTAL=t;print('TOTAL',round(TOTAL,2))
def captions(s):
  parts=[p.strip() for p in re.split(r'(?<=[.!?])\s+',s['voice']) if p.strip()]
  # merge very short / split long
  out=[]
  for p in parts:
    if len(p)>70:
      cs=[m.end() for m in re.finditer(r',\s',p)]
      if cs:
        c=min(cs,key=lambda i:abs(i-len(p)/2))
        if abs(c-len(p)/2)<len(p)*0.3:out+=[p[:c].strip(),p[c:].strip()];continue
      ws=p.split();h=len(ws)//2;out+=[' '.join(ws[:h]),' '.join(ws[h:])]
    else:out.append(p)
  tot=sum(len(x) for x in out);c=0;res=[]
  for x in out:
    a=c/tot*s['vd'];c+=len(x);res.append((a,c/tot*s['vd'],x))
  return res
for s in sc:s['caps']=captions(s)
def text(d,xy,t,f,fill=WHITE,anchor='la'):d.text(xy,t,font=f,fill=fill,anchor=anchor)
def card(d,box,fill=CARD,outline=LINE,r=18,w=2):d.rounded_rectangle(box,radius=r,fill=fill,outline=outline,width=w)
def pill(d,xy,t,fg,bg,size=24,anchor='l'):
  f=F(size,'Bold');b=d.textbbox((0,0),t,font=f);w=b[2]-b[0];x,y=xy
  if anchor=='r':x-=w+36
  d.rounded_rectangle((x,y,x+w+36,y+size+22),radius=(size+22)//2,fill=bg);text(d,(x+18,y+9),t,f,fg)
def base(label=None):
  im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im)
  for gx in range(0,W,96):d.line((gx,0,gx,H),fill=(12,18,25))
  for gy in range(0,H,96):d.line((0,gy,W,gy),fill=(12,18,25))
  text(d,(70,46),'Snap',F(34,'ExtraBold'));text(d,(70+d.textlength('Snap',font=F(34,'ExtraBold')),46),'Guard',F(34,'ExtraBold'),MINT)
  pill(d,(W-70,40),'TESTNET ONLY  /  PAPER TRADES',MINT,(19,42,34),22,'r')
  if label:text(d,(W//2,64),label,F(22,'Bold'),MUTED,'mm')
  return im,d
def term(d,box,lines,title,fs=30):
  card(d,box,fill=(10,15,22));x0,y0,x1,y1=box;text(d,(x0+30,y0+24),title,F(20,'Bold'),CYAN)
  for i,(c,l) in enumerate(lines):text(d,(x0+30,y0+72+i*(fs+16)),l,F(fs,mono=True),c)
# ---------- static scenes
def S1(lt):
  im,d=base('EVERY SECOND COUNTS  /  REACTIVE OMNI BUILDATHON')
  text(d,(W//2,250),'Stop-loss and take-profit',F(84,'ExtraBold'),WHITE,'mm')
  text(d,(W//2,350),'that fire by themselves.',F(84,'ExtraBold'),MINT,'mm')
  items=[('THE USUAL WAY','A keeper bot on a server you keep online.',RED),('THE RISK','If it lags or crashes, your stop fires late.',AMBER),('SNAPGUARD','Reactive Network watches and closes the trade.',MINT)]
  for i,(a,b,c) in enumerate(items):
    if lt<1.2+i*3.2:continue
    x=110+i*580;card(d,(x,470,x+540,700));text(d,(x+34,510),a,F(22,'Bold'),c);
    for j,ln in enumerate(wrap(b,F(34,'SemiBold'),470)):text(d,(x+34,560+j*48),ln,F(34,'SemiBold'))
  return im
def wrap(t,f,w):
  out=[];cur=''
  for wd in t.split():
    n=(cur+' '+wd).strip()
    if ImageDraw.Draw(Image.new('RGB',(1,1))).textlength(n,font=f)>w:out.append(cur);cur=wd
    else:cur=n
  return out+[cur]
def arrow(d,a,b,col):
  d.line((a,b),fill=col,width=6);x,y=b;ax,ay=a;ang=math.atan2(y-ay,x-ax)
  for s in(-1,1):d.line((x,y,x-26*math.cos(ang+s*.45),y-26*math.sin(ang+s*.45)),fill=col,width=6)
def S2(lt):
  im,d=base('HOW IT WORKS')
  boxes=[(90,250,620,620,'BASE SEPOLIA','MockPricePool','emits Sync (price update)','PaperVault','emits PositionOpened',CYAN),
         (695,250,1225,620,'REACTIVE LASNA','SnapGuardReactive','subscribes to both events','react()','checks stop and target',MINT),
         (1300,250,1830,620,'BASE SEPOLIA','PaperVault','executeExit() callback','records','close price + latency',CYAN)]
  for i,(x0,y0,x1,y1,ch,a,b,c,e,col) in enumerate(boxes):
    if lt<0.8+i*3.5:continue
    card(d,(x0,y0,x1,y1),outline=col);text(d,(x0+34,y0+30),ch,F(22,'Bold'),col)
    text(d,(x0+34,y0+90),a,F(44,'ExtraBold'));text(d,(x0+34,y0+150),b,F(28,mono=True),MUTED)
    text(d,(x0+34,y0+230),c,F(44,'ExtraBold'));text(d,(x0+34,y0+290),e,F(28,mono=True),MUTED)
  if lt>3.5:arrow(d,(625,435),(688,435),AMBER)
  if lt>7:arrow(d,(1230,435),(1293,435),AMBER)
  if lt>9:
    card(d,(300,700,1620,840),outline=AMBER);text(d,(W//2,742),'Price crosses stop or target  >  Reactive callback  >  trade closed',F(34,'Bold'),AMBER,'mm')
    text(d,(W//2,800),'No keeper bot. No off-chain server in the loop.',F(28),WHITE,'mm')
  return im
def shot(path,crop=None,maxw=1720,maxh=730):
  im=Image.open(path).convert('RGB')
  if crop:im=im.crop(crop)
  s=min(maxw/im.width,maxh/im.height);return im.resize((int(im.width*s),int(im.height*s)),Image.LANCZOS),s
def explorer(img,cropbox,title,sub,hls,lt,s):
  im,d=base(title)
  sh,k=shot(P/'shots'/img,cropbox);x=(W-sh.width)//2;y=120;im.paste(sh,(x,y));d.rectangle((x-2,y-2,x+sh.width+1,y+sh.height+1),outline=LINE,width=2)
  ox,oy=cropbox[:2] if cropbox else (0,0)
  for (bx0,by0,bx1,by1,t0) in hls:
    if lt>=t0:d.rounded_rectangle((x+(bx0-ox)*k,y+(by0-oy)*k,x+(bx1-ox)*k,y+(by1-oy)*k),radius=10,outline=AMBER,width=5)
  text(d,(W//2,y+sh.height+30),sub,F(26,'SemiBold'),CYAN,'mm')
  return im
def E1(lt,s):return explorer('sl_origin.png',(90,120,1500,820),'BASESCAN  /  BASE SEPOLIA  /  STEP 3: PRICE MOVE','movePrice(1700) on MockPricePool. Basescan shows UTC: 03:26:23 PM UTC = 16:26:23 WAT',[(130,370,1300,530,0.8),(450,240,780,290,2.5)],lt,s)
def E2(lt,s):
  if lt<4.6:return explorer('sl_reactive.png',(0,90,1585,760),'REACTSCAN  /  REACTIVE LASNA  /  STEP 4: REACT','trigger(): the log from MockPricePool on chain 84532, block 56580571',[(30,520,1560,705,0.6)],lt,s)
  return explorer('sl_reactive.png',(0,780,1585,1300),'REACTSCAN  /  REACTIVE LASNA  /  STEP 4: CALLBACK REQUEST','Callback to Base Sepolia: requested, relayed, sent, included, CONFIRMED',[(30,800,1560,900,4.8),(30,900,1560,1240,5.6)],lt,s)
def E3(lt,s):return explorer('sl_callback.png',(90,120,1500,820),'BASESCAN  /  BASE SEPOLIA  /  STEP 5: CALLBACK CLOSES THE TRADE','Deliver Callback via Reactive proxy 0x476F...3585. 03:26:24 PM UTC = 16:26:24 WAT',[(110,225,800,290,0.6),(130,370,1300,530,2.5)],lt,s)
def lat(k):
  out=[];f=(LIVE/f'latency-{k}.txt').read_text().split('\n')
  for l in f:
    if not l.strip():continue
    p=l.split()
    if p[0].endswith('_tx'):out.append((WHITE,f'{p[0]:<12} {p[1][:10]}...{p[1][-4:]}  {p[2]}  {p[3]}'))
    else:out.append((MINT if 'full' in p[0] else MUTED,f'{p[0]:<24} {p[1]}'))
  return out
def E4(lt,s):
  im,d=base('LATENCY FROM BLOCK TIMESTAMPS  /  script/measure_latency.sh')
  term(d,(110,130,1810,500),lat('StopLoss'),'STOP-LOSS  position #7',27)
  term(d,(110,530,1810,900),lat('TakeProfit'),'TAKE-PROFIT  position #8',27)
  text(d,(W//2,930),'Block timestamps are whole seconds and each chain has its own clock, so a hop can read 0 or -1.',F(24),MUTED,'mm')
  return im
def T1(lt,s):
  im,d=base('FOUNDRY TESTS  /  forge test')
  ls=[l for l in (P/'forge-test.txt').read_text().split('\n') if l.startswith('[PASS]') or 'Suite result' in l]
  lines=[(CYAN,'$ forge test')]+[(MINT if 'PASS' in l else WHITE,l.split(' (gas')[0].replace('Suite result: ','')[:72]) for l in ls]
  n=min(len(lines),1+int(max(0,lt-0.5)/0.45));term(d,(250,140,1670,900),lines[:n],'TERMINAL',30)
  return im
def C1(lt,s):
  im,d=base("WHAT'S NEXT")
  card(d,(160,150,1760,420));text(d,(210,190),'NEXT',F(22,'Bold'),CYAN)
  text(d,(210,240),'Trailing stops',F(46,'Bold'));text(d,(210,310),'Real pool price feeds (after audits)',F(46,'Bold'))
  card(d,(160,450,1760,780));text(d,(210,490),'OPEN SOURCE',F(22,'Bold'),MINT);text(d,(210,540),'github.com/Folorunso800/snapguard',F(46,'Bold',mono=False),WHITE)
  for i,l in enumerate(['PaperVault         0x35744e2bCDd640610D0397cB6501d05de8540339  Base Sepolia','SnapGuardReactive  0xDe45d86EC0f3b821dC87fC15e201D0344d7E8d88  Lasna','MockPricePool      0xc2a97f743aB0a9ceadC576F89A3575FfC1926503  Base Sepolia']):text(d,(210,620+i*44),l,F(25,mono=True),MUTED)
  card(d,(160,810,1760,900),fill=(42,18,18),outline=(110,50,50));text(d,(W//2,855),'Testnet only. Paper trades. No real funds. Not financial advice.',F(32,'Bold'),RED,'mm')
  return im
STATIC={'S1':lambda lt,s:S1(lt),'S2':lambda lt,s:S2(lt),'E1':E1,'E2':E2,'E3':E3,'E4':E4,'T1':T1,'C1':C1}
# ---------- live
import bisect
@functools.lru_cache(maxsize=64)
def recframe(i):
  im=Image.open(LIVE/'frames'/f'{frames[i][0]:05d}.jpg').convert('RGB').crop((0,0,1920,1062))
  return im.resize((1660,918),Image.LANCZOS)
def live(s,lt):
  ct=min(lt,s['clip']);rect=s['a']+ct;i=max(0,bisect.bisect_right(ftimes,rect)-1)
  im=Image.new('RGB',(W,H),BG);d=ImageDraw.Draw(im);im.paste(recframe(i),(130,8));d.rectangle((128,6,1791,927),outline=LINE,width=2)
  frozen=lt>s['clip']
  if frozen:pill(d,(1900,1022),'PAUSED TO EXPLAIN',AMBER,(50,40,15),18,'r')
  else:pill(d,(1900,1022),'LIVE RECORDING  /  REAL TIME',MINT,(16,46,34),18,'r')
  if s.get('cut') and lt<5:pill(d,(20,1022),'23 s cut: terminal waited on a slow RPC receipt (trade was already closed)',WHITE,(40,40,52),18)
  return im
def frame(t):
  k=0
  while k<len(sc)-1 and t>=sc[k+1]['start']:k+=1
  s=sc[k];lt=t-s['start']
  im=live(s,lt) if s['kind']=='live' else STATIC[s['id']](lt,s)
  d=ImageDraw.Draw(im)
  # caption
  ct=lt-s['lead'];cap=None
  for a,b,x in s['caps']:
    if a-0.05<=ct<b+0.25:cap=x
  if cap:
    f=F(38,'SemiBold');w=d.textlength(cap,font=f)
    d.rounded_rectangle((W/2-w/2-26,948,W/2+w/2+26,1012),radius=14,fill=(0,0,0))
    text(d,(W//2,980),cap,f,WHITE,'mm')
  d.rectangle((0,H-8,W,H),fill=(20,28,36));d.rectangle((0,H-8,int(W*t/TOTAL),H),fill=MINT)
  if s['kind']!='live':
    fade=min(1,lt/0.3)
    if fade<1:im=Image.blend(Image.new('RGB',(W,H),BG),im,fade)
  return im
if __name__=='__main__':
  import sys
  if len(sys.argv)>1 and sys.argv[1]=='preview':
    for s in sc:frame(s['start']+min(s['dur']-0.2,max(s['dur']*0.75,1))).save(P/'preview'/f"{s['id']}.jpg",quality=85)
    sys.exit()
  json.dump([{k:s[k] for k in('id','start','dur','vd','lead','voice')} for s in sc],open(P/'timeline.json','w'),indent=1)
  cmd=['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r',str(FPS),'-i','-','-c:v','libx264','-preset','medium','-crf','20','-pix_fmt','yuv420p',str(P/'silent.mp4')]
  pr=subprocess.Popen(cmd,stdin=subprocess.PIPE);N=math.ceil(TOTAL*FPS);cache={}
  for n in range(N):
    t=n/FPS;k=0
    while k<len(sc)-1 and t>=sc[k+1]['start']:k+=1
    s=sc[k];lt=t-s['start']
    # static scenes change only at stage times / fades: cache per 0.1s bucket
    if s['kind']!='live' and lt>0.3:
      key=(s['id'],int(lt*10),None)
    else:key=None
    pr.stdin.write(frame(t).tobytes())
    if n%900==0:print('frame',n,'/',N,flush=True)
  pr.stdin.close();assert pr.wait()==0;print('done')
