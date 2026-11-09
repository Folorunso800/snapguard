import asyncio,time,json,pathlib,sys
from playwright.async_api import async_playwright
P=pathlib.Path(__file__).parent;F=P/'frames';F.mkdir(exist_ok=True)
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch(executable_path='/usr/bin/google-chrome',args=['--headless=new']);pg=await b.new_page(viewport={'width':1920,'height':1080});cl=open(P/'console.log','w');pg.on('console',lambda m:(cl.write(f'{time.time():.2f} {m.text}\n'),cl.flush()))
    await pg.goto('http://localhost:8765/dashboard.html');await asyncio.sleep(2)
    idx=[];n=0
    while not (P/'STOP').exists():
      t=time.time();await pg.screenshot(path=str(F/f'{n:05d}.jpg'),type='jpeg',quality=88);idx.append([n,t]);n+=1
      if n%100==0:(P/'frames.json').write_text(json.dumps(idx))
      await asyncio.sleep(max(0,0.1-(time.time()-t)))
    (P/'frames.json').write_text(json.dumps(idx));await b.close()
asyncio.run(main())
