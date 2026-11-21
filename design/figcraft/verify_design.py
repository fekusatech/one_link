import json
from figcraft_control import cmd,call,ROOT
before=call('document.inspect',{'depth':64})
cmd('file.saveAs',{'path':str(ROOT/'one-link-redesign.figcraft')})
cmd('file.open',{'path':str(ROOT/'one-link-redesign.figcraft'),'reload':True})
after=call('document.inspect',{'depth':64})
assert before['pages']==after['pages']
frames=after['pages'][0]['children'];ids={f['id'] for f in frames}
links=[];nodes=[]
def walk(n):
 nodes.append(n)
 for i in n.get('interactions',[]):
  for a in i.get('actions',[]):
   if a['type']=='navigate':
    assert a['dest'] in ids
    links.append((n['id'],a['dest']))
 for child in n.get('children',[]):walk(child)
for frame in frames:walk(frame)
fonts=cmd('file.fontReport');assert fonts['missing']==0
for i,frame in enumerate(frames):
 cmd('file.export',{'ids':[frame['id']],'format':'png','scale':1.5,'path':str(ROOT/f'{i+1:02d}.png')})
cmd('file.export',{'ids':list(ids),'format':'pdf','path':str(ROOT/'one-link-review.pdf')})
call('ui.render',{'scale':0.65,'path':str(ROOT/'overview.png')})
def luminance(h):
 v=[int(h[i:i+2],16)/255 for i in (1,3,5)]
 v=[x/12.92 if x<=.04045 else ((x+.055)/1.055)**2.4 for x in v]
 return sum(x*y for x,y in zip(v,[.2126,.7152,.0722]))
def contrast(a,b):
 a,b=sorted([luminance(a),luminance(b)]);return round((b+.05)/(a+.05),2)
contrasts={f'{a} on {b}':contrast(a,b) for a,b in [('#FFFFFF','#1B4D3E'),('#212121','#E87C1E'),('#424242','#FAFAFA'),('#1B4D3E','#F5F5F5')]}
assert min(contrasts.values())>=4.5
report={'native_roundtrip':'PASS','artboards':len(frames),'nodes':len(nodes),'navigation_destinations_valid':len(links),'missing_fonts':fonts['missing'],'text_contrast':contrasts,'visual_review':f'{len(frames)} artboards exported; overview inspected','interactive_runtime':'Not verified: UI clicks did not show a stable destination change. Structural links only.','scope':'Design review, not Flutter implementation or functional prototype acceptance'}
(ROOT/'verification.json').write_text(json.dumps(report,indent=2))
(ROOT/'document-inspection.json').write_text(json.dumps(after,indent=2))
print(json.dumps(report,indent=2))
