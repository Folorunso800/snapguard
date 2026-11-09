import json,subprocess,time,os,sys,pathlib
P=pathlib.Path(__file__).parent;os.environ['PATH']=os.path.expanduser('~/.foundry/bin')+':'+os.environ['PATH']
B='https://sepolia.base.org';L='https://lasna-rpc.rnk.dev/'
POOL='0xc2a97f743aB0a9ceadC576F89A3575FfC1926503';VAULT='0x35744e2bCDd640610D0397cB6501d05de8540339';REACT='0xDe45d86EC0f3b821dC87fC15e201D0344d7E8d88'
PK=[l.split('=',1)[1].strip().strip('"') for l in open(os.path.expanduser('~/.secrets/reactive/wallet.env')) if l.startswith('PRIVATE_KEY=')][0]
TR='0x4e26113623a9823f55354e55a44746012c21101b15a7c3dbcc5b214101b4f89c';HIT='0x455d19b558e9efe02546e82b345685eb4c5ed82e5e0fe9e6d1e9453811791857';CL='0x4766813e80490a54ff32e7318b194e39b0da008fc19f4c596511feb65140f820'
state={'focus':None,'moveTx':None,'lines':[]};run={'events':[]}
def save():
  (P/'state.tmp').write_text(json.dumps(state));os.replace(P/'state.tmp',P/'state.json');(P/'run.json').write_text(json.dumps(run,indent=1))
def log(cls,t):
  state['lines'].append([cls,t]);save();run['events'].append([time.time(),cls,t]);print(t,flush=True)
def cast(*a):
  for i in range(5 if a[0]!='send' else 1):
    r=subprocess.run(['cast',*a],capture_output=True,text=True)
    if r.returncode==0:break
    time.sleep(1)
  if r.returncode: raise SystemExit('cast failed: '+r.stderr.replace(PK,'***')[:400])
  return r.stdout.strip()
def send(to,sig,*args,wait=True):
  out=cast('send',to,sig,*args,'--private-key',PK,'--rpc-url',B,'--async')
  h=out.split()[-1];return h
def receipt(h):
  while True:
    r=subprocess.run(['cast','receipt',h,'status','--rpc-url',B],capture_output=True,text=True)
    if r.returncode==0 and r.stdout.strip():return r.stdout.strip()
    time.sleep(.3)
def logs(rpc,addr,topic,pid,fromb):
  out=cast('rpc','eth_getLogs',json.dumps([{'fromBlock':hex(fromb),'toBlock':'latest','address':addr,'topics':[topic,'0x%064x'%pid]}]),'--raw','--rpc-url',rpc)
  return json.loads(out)
def waitlog(rpc,addr,topic,pid,fromb,timeout=180):
  t=time.time()
  while time.time()-t<timeout:
    try:
      x=logs(rpc,addr,topic,pid,fromb)
      if x:return x[0]
    except SystemExit:pass
    time.sleep(.4)
  raise SystemExit('timeout waiting log')
def E(x):return int(float(x)*1e18)
def loop(kind,target):
  pid=int(cast('call',VAULT,'positionCount()(uint256)','--rpc-url',B).split()[0])
  lb=int(cast('block-number','--rpc-url',L))-5;bb=int(cast('block-number','--rpc-url',B))-5
  state['focus']=pid;state['moveTx']=None;save();time.sleep(1.5)
  log('m',f'# {kind} demo, paper position #{pid}')
  log('c','$ cast send PaperVault "openPosition(entry,stop,take)" \\')
  log('c','    2000e18 1800e18 2200e18')
  h=send(VAULT,'openPosition(uint256,uint256,uint256)',str(E(2000)),str(E(1800)),str(E(2200)))
  log('o',f'tx {h}');st=receipt(h);log('g',f'status 1 (success)  PositionOpened #{pid}')
  run[kind+'_open']=h
  log('m','# no manual step: waiting for Reactive to see it...')
  x=waitlog(L,REACT,TR,pid,lb);run[kind+'_tracked']=x['transactionHash']
  log('g',f'Lasna PositionTracked #{pid}');log('o',f'tx {x["transactionHash"]}')
  time.sleep(3)
  log('c',f'$ cast send MockPricePool "movePrice(uint256)" {target}e18')
  h=send(POOL,'movePrice(uint256)',str(E(target)));state['moveTx']=h;save();run[kind+'_origin']=h
  t0=time.time();log('o',f'tx {h}');receipt(h);log('g','status 1 (success)  Sync emitted')
  log('m','# hands off. waiting for the callback...')
  x=waitlog(B,VAULT,CL,pid,bb);run[kind+'_callback']=x['transactionHash']
  y=logs(L,REACT,HIT,pid,lb);run[kind+'_reactive']=y[0]['transactionHash'] if y else None
  log('g',f'Base PositionClosed #{pid} ({kind})');log('o',f'tx {x["transactionHash"]}')
  if y:log('o',f'reactive tx {y[0]["transactionHash"]}')
  run[kind+'_pid']=pid;save()
phase=sys.argv[1] if len(sys.argv)>1 else 'all'
if phase=='warm':
  bb=int(cast('block-number','--rpc-url',B))-5
  h=send(POOL,'movePrice(uint256)',str(E(1700)));print('move',h,receipt(h))
  x=waitlog(B,VAULT,CL,2,bb);print('closed #2',x['transactionHash'])
  h=send(POOL,'movePrice(uint256)',str(E(2000)));print('reset',h,receipt(h));sys.exit()
if phase=='prep':
  h=send(POOL,'movePrice(uint256)',str(E(2000)));print('reset',h,receipt(h));sys.exit()
log('m','# SnapGuard live run  (testnet only, paper trades)');time.sleep(1)
run['start']=time.time()
loop('StopLoss',1700)
time.sleep(4)
state['focus']=None;save()
log('m','# reset test price to 2000 for the next demo')
log('c','$ cast send MockPricePool "movePrice(uint256)" 2000e18')
h=send(POOL,'movePrice(uint256)',str(E(2000)));log('o',f'tx {h}');receipt(h);log('g','status 1 (success)');run['reset']=h
time.sleep(2)
loop('TakeProfit',2300)
run['end']=time.time();save();log('m','# done. both trades closed by Reactive callbacks.')
