import socket,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent
def call(method,params={}):
 s=socket.create_connection(('127.0.0.1',7979),timeout=60); f=s.makefile('rwb');f.write((json.dumps({'id':1,'method':method,'params':params})+'\n').encode());f.flush(); r=json.loads(f.readline());s.close()
 if not r.get('ok'):raise RuntimeError(r)
 return r.get('result')
def cmd(command,params={}):return call('engine.execute',{'command':command,'params':params})
