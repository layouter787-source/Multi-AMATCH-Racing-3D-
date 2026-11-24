import numpy as np, math
from geo import *

def side_x(B,u,y=None):
    return B.HW(u)

def add_wheels_wells(mb,B,d,track,arch_extra=0.07):
    """forro da caixa de roda (meio tubo, so a parte de cima) DENTRO da carroceria"""
    for key in ('FL','FR','RL','RR'):
        base=d['FL'] if key[0]=='F' else d['RL']
        x=abs(base[0]);zc=base[2];sg=-1 if key[1]=='L' else 1
        Ra=d['R']+arch_extra+0.015
        u=B.u_of_z(zc);xo=B.HW(u)*0.93
        x0=sg*(x-0.22);x1=sg*xo
        n=24;ang=np.linspace(math.radians(-15),math.radians(195),n)
        V=[];F=[]
        for a in ang:
            y=d['R']+Ra*math.sin(a);z=zc+Ra*math.cos(a)
            V+=[[x0,max(y,0.03),z],[x1,max(y,0.03),z]]
        for i in range(n-1):
            a0=2*i;F+=[[a0,a0+1,a0+3],[a0,a0+3,a0+2]]
        F=np.array(F)
        # normais para dentro da caixa (visivel de quem olha a roda)
        Vv=np.array(V);fn=np.cross(Vv[F[:,1]]-Vv[F[:,0]],Vv[F[:,2]]-Vv[F[:,0]])
        cen=Vv[F].mean(axis=1);toward=np.array([x0,d['R'],zc])-cen
        if np.mean(np.sum(fn*toward,axis=1)<0)>0.5: F=F[:,[0,2,1]]
        mb.add('Trim',Vv,F,flat=True)
        # fundo da caixa (parede interna)
        poly=[(zc+Ra*math.cos(a),max(d['R']+Ra*math.sin(a),0.03)) for a in ang]
        mb.extrude('Trim',poly,x0,x0+sg*0.006,axis='x')

def add_mirrors(mb,B,d,belt_h):
    cabu=[u for u in B.us if B.info[int(np.argmin(abs(B.us-u)))][0]>0.4]
    if not cabu: return
    u0=min(cabu);z=B.z(u0)+0.30
    for sg in (-1,1):
        x=B.HW(u0+0.04)*0.80*sg
        y=belt_h+0.17
        mb.cyl('Trim',[x,y-0.05,z],[x+sg*0.10,y,z],0.012,seg=6)
        mb.ell('Paint',[x+sg*0.17,y+0.01,z],[0.10,0.055,0.075],seg=14,rings=8)
        mb.box('Glass',[x+sg*0.17,y+0.01,z-0.065],[0.15,0.08,0.01])

def add_doors(mb,B,d,belt_h,sill=0.20):
    cab=[(i,B.info[i]) for i in range(len(B.us)) if B.info[i][0]>0.3]
    z0=B.z(B.us[cab[0][0]])-0.05;z1=z0+1.18
    for sg in (-1,1):
        for zz in (z0,z1):
            u=B.u_of_z(zz);x=B.HW(u)*0.985*sg
            mb.box('Trim',[x,(belt_h+B.B(u)+sill)/2,zz],[0.008,belt_h-B.B(u)-sill,0.008])
        u=B.u_of_z(z0+0.55);x=B.HW(u)*0.987*sg
        mb.box('Trim',[x,belt_h-0.04,z0+0.55],[0.008,0.012,1.1*0.9])   # linha da base da janela
        u=B.u_of_z(z1-0.20);x=B.HW(u)*0.99*sg
        mb.box('Trim',[x+sg*0.006,belt_h-0.10,z1-0.20],[0.014,0.028,0.16])  # macaneta

def add_lights(mb,B,d,style='led',front_u=0.07,tail='bar'):
    zf=B.znose+0.42
    for sg in (-1,1):
        u=B.u_of_z(zf);x=B.HW(u)*0.66*sg;y=B.T(u)-0.07
        if style=='round':
            mb.cyl('Trim',[x,y,zf-0.02],[x,y,zf-0.075],0.092,seg=22)
            mb.cyl('Headlight',[x,y,zf-0.07],[x,y,zf-0.085],0.075,seg=22)
        else:
            mb.ell('Trim',[x,y,zf],[0.21,0.065,0.14],seg=16,rings=8)
            mb.ell('Headlight',[x,y,zf-0.035],[0.17,0.04,0.10],seg=16,rings=8)
    ze=B.znose+B.Lm
    u=0.965
    if tail=='bar':
        mb.box('Taillight',[0,B.T(u)-0.11,ze-0.075],[B.HW(u)*1.55,0.042,0.03])
    elif tail=='ring':
        for sg in (-1,1):
            mb.cyl('Taillight',[sg*0.42,B.T(u)-0.18,ze-0.07],[sg*0.42,B.T(u)-0.18,ze-0.085],0.075,seg=20)
    for sg in (-1,1):
        mb.box('Taillight',[sg*(B.HW(u)*0.80),B.T(u)-0.14,ze-0.08],[0.30,0.05,0.025])

def add_intakes(mb,B,d,nose_h=0.22):
    zf=B.znose
    u=B.u_of_z(zf+0.05)
    w=B.HW(u)*1.55
    mb.box('Trim',[0,B.B(u)+0.20,zf+0.075],[w,nose_h,0.05])     # grade inferior
    for sg in (-1,1):
        mb.box('Trim',[sg*(B.HW(u)*1.1),B.B(u)+0.20,zf+0.20],[0.50,0.16,0.05])

def add_splitter(mb,B,d,depth=0.38,mat='Carbon'):
    zf=B.znose;u=B.u_of_z(zf+0.1)
    mb.box(mat,[0,B.B(u)-0.005,zf+depth/2-0.04],[B.HW(u)*1.9,0.026,depth])
    ze=B.znose+B.Lm
    u=B.u_of_z(ze-0.2)
    mb.box(mat,[0,B.B(u)+0.02,ze-0.12],[B.HW(u)*1.7,0.03,0.40])
    for k in range(-3,4):  # aletas do difusor
        mb.box('Carbon',[k*0.20,B.B(u)+0.09,ze-0.18],[0.015,0.14,0.34])

def add_exhaust(mb,B,d,pos=((-0.2,),(0.2,)),r=0.055,y_off=0.20):
    ze=B.znose+B.Lm;u=0.97
    for (x,) in pos:
        mb.cyl('Metal',[x,B.B(u)+y_off,ze-0.10],[x,B.B(u)+y_off,ze+0.01],r,seg=18,cap=False)
        mb.cyl('Trim',[x,B.B(u)+y_off,ze-0.08],[x,B.B(u)+y_off,ze-0.075],r*0.92,seg=18)

def add_wing(mb,B,d,span=1.78,chord=0.30,height=0.30,z_back=0.10,aoa=-9,uprights=(-0.52,0.52),swan=True,endplate=0.16):
    ze=B.znose+B.Lm;zc=ze-z_back
    u=B.u_of_z(zc-0.1);deck=B.T(u)
    yb=deck+height
    prof=[(-chord/2,0.0),(-chord/2+0.02,0.03),(-chord*0.2,0.052),(chord*0.2,0.036),(chord/2,0.006),(chord/2-0.01,-0.012),(0.0,-0.022),(-chord*0.3,-0.014)]
    # flip: Z para tras = +z
    poly=[(p[0]+0.0,p[1]) for p in prof]
    t=MB();t.extrude('Carbon',poly,-span/2,span/2,axis='x')
    R=rotx(math.radians(aoa))
    # aplicar rotacao em torno do eixo X pelo centro
    for k,dd in t.m.items():
        V=np.vstack(dd['V']);Vr=V@R.T+np.array([0,yb,zc])
        N=np.vstack(dd['N'])@R.T
        mb.add(k,Vr,np.vstack(dd['F']),N)
    for sg in (-1,1):
        mb.box('Carbon',[sg*(span/2),yb+0.04,zc],[0.012,endplate,chord+0.08])
    for x in uprights:
        if swan:
            mb.box('Carbon',[x,(deck+yb)/2-0.01,zc-0.02],[0.035,yb-deck+0.02,0.10])
            mb.box('Carbon',[x,deck+0.015,zc-0.10],[0.05,0.03,0.25])
        else:
            mb.box('Carbon',[x,(deck+yb)/2,zc],[0.04,yb-deck,0.12])


def add_arch_lips(mb,B,d,arch_extra=0.07,mat='Trim'):
    """aro preto fino contornando a abertura da roda (esconde os dentes da malha)"""
    Nh=B.Nh
    for key in ('FL','FR','RL','RR'):
        base=d['FL'] if key[0]=='F' else d['RL']
        zc=base[2];sg=-1 if key[1]=='L' else 1
        Rl=d['R']+arch_extra+0.005
        pts=[]
        for a in np.linspace(math.radians(-8),math.radians(188),34):
            z=zc+Rl*math.cos(a);y=d['R']+Rl*math.sin(a)
            u=B.u_of_z(z);i=int(np.argmin(abs(B.us-u)))
            ys=B.grid[i,:Nh+1,1];xs=B.grid[i,:Nh+1,0]
            o=np.argsort(ys);x=float(np.interp(y,ys[o],xs[o]))
            pts.append((sg*(x+0.006),y,z))
        for p,q in zip(pts[:-1],pts[1:]):
            mb.cyl(mat,p,q,0.016,seg=6,cap=False)
