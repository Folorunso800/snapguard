import asyncio,json
from playwright.async_api import async_playwright
r=json.load(open('../live/run.json'))
U={'sl_origin':'https://sepolia.basescan.org/tx/'+r['StopLoss_origin'],'sl_reactive':'https://lasna.reactscan.net/tx/'+r['StopLoss_reactive'],'sl_callback':'https://sepolia.basescan.org/tx/'+r['StopLoss_callback'],
 'tp_origin':'https://sepolia.basescan.org/tx/'+r['TakeProfit_origin'],'tp_reactive':'https://lasna.reactscan.net/tx/'+r['TakeProfit_reactive'],'tp_callback':'https://sepolia.basescan.org/tx/'+r['TakeProfit_callback'],
 'sl_callback_logs':'https://sepolia.basescan.org/tx/'+r['StopLoss_callback']+'#eventlog'}
async def main():
  async with async_playwright() as p:
    b=await p.chromium.launch(executable_path='/usr/bin/google-chrome',args=['--headless=new','--disable-blink-features=AutomationControlled'])
    c=await b.new_context(viewport={'width':1600,'height':1000},user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36',color_scheme='dark')
    for k,u in U.items():
      pg=await c.new_page()
      try:
        await pg.goto(u,wait_until='domcontentloaded',timeout=45000);await asyncio.sleep(8)
        await pg.screenshot(path=f'shots/{k}.png');print(k,await pg.title())
      except Exception as e:print(k,'ERR',e)
      await pg.close()
    await b.close()
asyncio.run(main())
