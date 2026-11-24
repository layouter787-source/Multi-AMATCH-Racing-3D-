import numpy as np
from PIL import Image, ImageDraw
from geo import MATS

def render(mbs,cam_pos,target=(0,0.55,0),size=(900,520),fov=32,paint=None,bg=(205,208,214),light=(0.5,0.9,-0.6)):
    cam=np.array(cam_pos,float);tg=np.array(target,float)
    f=tg-cam;f/=np.linalg.norm(f);r=np.cross(f,[0,1,0]);r/=np.linalg.norm(r);u=np.cross(r,f)
    tris=[]
    L=np.array(light,float);L/=np.linalg.norm(L)
    for mb,off in mbs:
        for k,d in mb.m.items():
            V=np.vstack(d['V'])+off;F=np.vstack(d['F'])
            c=np.array(MATS[k]['c'][:3]) if not(paint is not None and k=='Paint') else np.array(paint)
            if k=='Glass': c=np.array([0.10,0.14,0.2])
            if k=='Headlight': c=np.array([1,1,0.85])
            P=V-cam;x=P@r;y=P@u;z=P@f
            sc=size[1]/2/np.tan(np.radians(fov/2))
            sx=size[0]/2+x/np.maximum(z,0.1)*sc;sy=size[1]/2-y/np.maximum(z,0.1)*sc
            a,b,cc=V[F[:,0]],V[F[:,1]],V[F[:,2]]
            n=np.cross(b-a,cc-a);l=np.linalg.norm(n,axis=1,keepdims=True);l[l==0]=1;n=n/l
            cen=(a+b+cc)/3
            dep=((cen-cam)@f)
            for i in range(len(F)):
                if z[F[i]].min()<0.2: continue
                v=n[i]
                # dupla face: usar o lado voltado para a camera
                if v@(cen[i]-cam)>0: v=-v
                sh=0.30+0.70*max(0,v@L)
                if MATS[k]['m']>0.4: sh=sh*0.8+0.25*max(0,(v@(-f)))**4*1.0
                col=tuple(int(255*min(1,max(0,t*sh))) for t in c)
                tris.append((dep[i],[(sx[F[i][0]],sy[F[i][0]]),(sx[F[i][1]],sy[F[i][1]]),(sx[F[i][2]],sy[F[i][2]])],col))
    tris.sort(key=lambda t:-t[0])
    im=Image.new('RGB',size,bg);dr=ImageDraw.Draw(im)
    for _,p,col in tris: dr.polygon(p,fill=col)
    return im
