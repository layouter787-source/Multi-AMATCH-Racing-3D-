import sys,numpy as np
from carbuild import *
from details import *
from preview import render
from PIL import Image

CFG={
 'gt3rs':dict(wing_cut=0.86,rear_deck=None,body=dict(carbon=[(0.06,0.30,0.55),(0.43,0.62,0.55)],sill_black=True),
    wheels=dict(wf=0.265,wr=0.32,nsp=10,style='multi',rim=0.74),light='round',tail='bar',
    wing=dict(span=1.82,chord=0.32,height=0.34,z_back=0.14,aoa=-8,swan=True),exhaust=((-0.2,),(0.2,)),splitter=True),

 'sf90':dict(wing_cut=None,body=dict(carbon=[(0.42,0.60,0.30)],sill_black=True),
    wheels=dict(wf=0.255,wr=0.315,nsp=5,style='multi',rim=0.74),light='led',tail='ring',
    wing=dict(span=1.35,chord=0.20,height=0.05,z_back=0.28,aoa=-4,swan=False,uprights=(-0.5,0.5),endplate=0.07),exhaust=((-0.12,),(0.12,)),splitter=True),
 'valkyrie':dict(wing_cut=None,body=dict(carbon=[(0.30,0.70,0.12)],sill_black=False,fcab=0.62),
    wheels=dict(wf=0.275,wr=0.335,nsp=10,style='multi',rim=0.76),light='led',tail='ring',
    wing=dict(span=1.55,chord=0.34,height=0.20,z_back=0.22,aoa=-7,swan=False,uprights=(-0.62,0.62),endplate=0.22),exhaust=((-0.1,),(0.1,)),splitter=True),
 'p911ts':dict(src='gt3rs',wing_cut=0.86,body=dict(carbon=[],sill_black=False),
    wheels=dict(wf=0.245,wr=0.305,nsp=5,style='multi',rim=0.74),light='round',tail='bar',wing=None,exhaust=((-0.28,),(0.28,)),splitter=False),
 'revuelto':dict(src='sf90',wing_cut=None,body=dict(carbon=[(0.42,0.60,0.30)],sill_black=True),
    wheels=dict(wf=0.255,wr=0.325,nsp=5,style='multi',rim=0.74),light='led',tail='bar',
    wing=dict(span=1.45,chord=0.22,height=0.06,z_back=0.28,aoa=-4,swan=False,uprights=(-0.5,0.5),endplate=0.07),exhaust=((-0.12,),(0.12,)),splitter=True),
 'mclaren750s':dict(src='valkyrie',wing_cut=None,body=dict(carbon=[(0.30,0.70,0.12)],sill_black=True,fcab=0.70),
    wheels=dict(wf=0.245,wr=0.305,nsp=10,style='multi',rim=0.74),light='led',tail='bar',
    wing=dict(span=1.5,chord=0.28,height=0.16,z_back=0.22,aoa=-6,swan=False,uprights=(-0.55,0.55),endplate=0.12),exhaust=((-0.1,),(0.1,)),splitter=True),
}

def build(key,preview=True):
    cars=parse_cars();d=cars[key];cf=CFG[key]
    B=Body(cf.get('src',key),d,wing_cut=cf['wing_cut'],rear_deck=cf.get('rear_deck'))
    mb=MB();build_body(mb,B,**cf['body'])
    belt_h=B.belt_h
    add_wheels_wells(mb,B,d,None);add_arch_lips(mb,B,d)
    add_mirrors(mb,B,d,belt_h);add_doors(mb,B,d,belt_h)
    add_lights(mb,B,d,style=cf['light'],tail=cf['tail'])
    add_intakes(mb,B,d)
    if cf.get('splitter'): add_splitter(mb,B,d)
    add_exhaust(mb,B,d,pos=cf['exhaust'])
    if cf.get('wing'): add_wing(mb,B,d,**cf['wing'])
    wh={}
    wc=cf['wheels']
    for k in ('FL','FR','RL','RR'):
        w=wc['wf'] if k[0]=='F' else wc['wr']
        wh[k]=wheel_mesh(d['R'],w,style=wc['style'],nsp=wc['nsp'],outward=-1 if k[1]=='L' else 1,rim_frac=wc['rim'])
    return d,B,mb,wh

if __name__=='__main__':
    key=sys.argv[1];d,B,mb,wh=build(key)
    mbs=[(mb,0)]
    for k,w in wh.items():
        base=d['FL'] if k[0]=='F' else d['RL']
        mbs.append((w,np.array([(-1 if k[1]=='L' else 1)*abs(base[0]),d['R'],base[2]])))
    paint=d['paint'][:3]
    if len(sys.argv)>2: d['paint']=d['paint']
    cams=[((-5.8,1.6,-5.2),(0,0.6,0)),((-8.5,0.65,0),(0,0.6,0)),((5.8,1.7,5.5),(0,0.6,0)),((0,0.55,-8),(0,0.65,0))]
    ims=[render(mbs,c,t,paint=paint,size=(900,540),fov=30) for c,t in cams]
    W=Image.new('RGB',(1800,1080))
    for i,im in enumerate(ims): W.paste(im,((i%2)*900,(i//2)*540))
    W.save(f'prev_{key}.png')
    print('done',{k:sum(len(f) for f in v['F']) for k,v in mb.m.items()})
