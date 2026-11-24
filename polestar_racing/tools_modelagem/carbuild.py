import numpy as np, cv2, re, math
from scipy import ndimage as ndi
from geo import *
from extract import SPECS, mask_of

def parse_cars(path='/home/claude/proj/polestar_racing/cars_data.gd'):
    s=open(path).read();out={}
    parts=re.split(r'\n    "(\w+)": \{',s)
    for i in range(1,len(parts),2):
        k,b=parts[i],parts[i+1]
        g=lambda key:float(re.search(r'"%s": ([\d.]+)'%key,b).group(1))
        w=lambda key:[float(x) for x in re.search(r'"%s": Vector3\(([-\d., ]+)\)'%key,b).group(1).split(',')]
        col=[float(x) for x in re.search(r'"paint": Color\(([\d., ]+)\)',b).group(1).split(',')]
        cab=re.findall(r'"pos": Vector3\(([-\d., ]+)\), "size": Vector3\(([-\d., ]+)\)',b)
        out[k]=dict(L=g('length'),W=g('width'),H=g('height'),R=g('wheel_radius'),FL=w('FL'),RL=w('RL'),paint=col,
            cabin=[[float(x) for x in cab[1][0].split(',')],[float(x) for x in cab[1][1].split(',')]])
    return out

def smooth(a,sig): return ndi.gaussian_filter1d(a,sig,mode='nearest')

class Body:
    """perfis (em metros) vindos das silhuetas do desenho tecnico"""
    def __init__(s,key,d,wing_cut=None,rear_deck=None):
        sp=SPECS[key];im=cv2.imread('/mnt/user-data/uploads/'+sp['f'])
        ms=mask_of(im,sp['side'],sp['thr']);mt=mask_of(im,sp['top'],sp['thr'])
        k=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(9,9))
        ms=cv2.morphologyEx(ms.astype(np.uint8),cv2.MORPH_OPEN,k).astype(bool)
        kt=cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(31,31))
        mt=cv2.morphologyEx(mt.astype(np.uint8),cv2.MORPH_OPEN,kt).astype(bool)
        cols=np.where(ms.any(0))[0];x0,x1=cols[0],cols[-1]
        # rodas: circulos (Hough) com raio esperado; escolhe o par que bate com a distancia entre eixos
        sx0,sy0,sx1,sy1=sp['side'];crop=cv2.cvtColor(im[sy0:sy1,sx0:sx1],cv2.COLOR_BGR2GRAY);crop=cv2.medianBlur(crop,5)
        Wpx=x1-x0+1;ppm=Wpx/d['L'];rpx=d['R']*ppm
        wb=d['RL'][2]-d['FL'][2]
        cs=cv2.HoughCircles(crop,cv2.HOUGH_GRADIENT,dp=1,minDist=rpx,param1=100,param2=28,minRadius=int(rpx*0.85),maxRadius=int(rpx*1.12))
        best=None
        if cs is not None:
            cs=cs[0]
            for i,p in enumerate(cs):
                for q in cs[i+1:]:
                    sc=abs(abs(p[0]-q[0])-wb*ppm)+3*abs(p[1]-q[1])
                    if best is None or sc<best[0]: best=(sc,p,q)
        if best is not None and best[0]<0.12*wb*ppm:
            pk=sorted([best[1],best[2]],key=lambda t:t[0]);fa=(pk[0][0],pk[0][1],pk[0][2]);ra=(pk[1][0],pk[1][1],pk[1][2])
        else:
            print('  [fallback eixo]');fa=(x0+(d['L']/2+d['FL'][2])*ppm,0,0);ra=(fa[0]+wb*ppm,0,0)
        s.ppm=ppm
        fa_rel=fa[0]-x0;ra_rel=ra[0]-x0
        s.znose=d['FL'][2]-fa_rel/ppm;zrear=d['RL'][2]+(Wpx-1-ra_rel)/ppm
        s.Lm=zrear-s.znose
        s._px=np.array([0,fa_rel,ra_rel,Wpx-1.0]);s._z=np.array([s.znose,d['FL'][2],d['RL'][2],zrear])
        ground=np.where(ms.any(1))[0].max()
        s.n=Wpx;ytop=np.zeros(Wpx);ybot=np.zeros(Wpx)
        for i in range(Wpx):
            r=np.where(ms[:,x0+i])[0];ytop[i]=r.min();ybot[i]=r.max()
        top=(ground-ytop)/ppm;bot=(ground-ybot)/ppm
        # fundo do corpo nos vaos das rodas
        for wx in (fa[0],ra[0]):
            lo=int(wx-x0-d['R']*ppm*1.05);hi=int(wx-x0+d['R']*ppm*1.05)
            lo=max(lo,0);hi=min(hi,Wpx-1)
            a,b=max(lo-6,0),min(hi+6,Wpx-1)
            bot[lo:hi+1]=np.interp(np.arange(lo,hi+1),[a,b],[bot[a],bot[b]])
        s.wheel_img=(fa,ra,ground)
        # largura (vista superior)
        tx0,ty0,tx1,ty1=sp['top']
        tcols=np.where(mt.any(0))[0];t0,t1=tcols[0],tcols[-1]
        hw=np.zeros(t1-t0+1)
        for i in range(len(hw)):
            r=np.where(mt[:,t0+i])[0];hw[i]=(r.max()-r.min())/2
        hw=hw/hw.max()*d['W']/2
        self_u=np.linspace(0,1,Wpx);tu=np.linspace(0,1,len(hw))
        hw=np.interp(self_u,tu,hw)
        s.u=self_u;s.top=smooth(top,Wpx*0.014);s.bot=smooth(np.maximum(bot,0.05),Wpx*0.02)
        s.hw=smooth(ndi.median_filter(hw,size=int(Wpx*0.03)),Wpx*0.025)
        if wing_cut:
            c=int(wing_cut*Wpx);end=s.top[c]*0.0+ (rear_deck if rear_deck else s.top[c]*0.92)
            s.top[c:]=np.interp(np.arange(c,Wpx),[c,Wpx-1],[s.top[c],end])
        body_max=s.top[:int((wing_cut or 1.0)*Wpx)].max()
        k=d['H']/body_max
        if 0.8<k<1.4: s.top*=k;s.bot*=k
        s.top=np.maximum(s.top,s.bot+0.12)
        for wk in ('FL','RL'):
            wz=d[wk][2];need=abs(d[wk][0])+0.18
            uz=(wz-s.znose)/s.Lm;half=(d['R']+0.12)/s.Lm
            for i,uu in enumerate(s.u):
                t=abs(uu-uz)/half
                if t<1: s.hw[i]=max(s.hw[i],need*(0.5+0.5*math.cos(math.pi*t*0.5))+s.hw[i]*0*t)
        s.d=d;s.key=key
    # amostras em metros: u (0..1) -> valores
    def T(s,u): return float(np.interp(u,s.u,s.top))
    def B(s,u): return float(np.interp(u,s.u,s.bot))
    def HW(s,u): return float(np.interp(u,s.u,s.hw))
    def z(s,u): return float(np.interp(u*(s.n-1),s._px,s._z))
    def u_of_z(s,z): return float(np.interp(z,s._z,s._px))/(s.n-1)

def smoothstep(a,b,x):
    t=np.clip((x-a)/(b-a),0,1);return t*t*(3-2*t)

def build_body(mb,B,belt_frac=0.93,fcab=0.74,Ns=260,Nh=18,sill_black=True,arch_extra=0.07,carbon=()):
    d=B.d
    hood=np.median(B.top[int(0.12*B.n):int(0.25*B.n)])
    deck=np.median(B.top[int(0.82*B.n):int(0.92*B.n)])
    belt_h=belt_frac*min(hood,max(deck,hood*0.9)) if False else belt_frac*hood
    B.belt_h=belt_h
    us=np.linspace(0.0,1.0,Ns)
    # distribui mais estacoes nas pontas
    us=0.5-0.5*np.cos(np.pi*us)
    us=0.5*us+0.5*np.linspace(0,1,Ns)
    th=np.linspace(-np.pi/2,np.pi/2,Nh+1)
    M=2*Nh
    grid=np.zeros((Ns,M,3));info=[]
    for i,u in enumerate(us):
        top=B.T(u);bot=B.B(u);hw=max(B.HW(u),0.05)
        top=max(top,bot+0.1)
        cab=float(smoothstep(belt_h+0.02,belt_h+0.22,top))
        belt=min(belt_h,top-0.06) if top>belt_h else bot+(top-bot)*0.62
        belt=max(belt,bot+0.05)
        pu=0.80-0.38*cab
        pts=[]
        for t in th:
            s_,c_=math.sin(t),max(math.cos(t),0)
            if s_>=0:
                y=belt+(top-belt)*(s_**pu)
                x=hw*(c_**0.62)*(1-(1-fcab)*cab*(s_**1.1))
            else:
                y=belt-(belt-bot)*((-s_)**0.38)
                x=hw*(c_**0.55)
            pts.append((x,y))
        right=pts                       # de baixo (idx0) para cima (idx Nh)
        left=[(-x,y) for x,y in reversed(pts[1:-1])]
        ring=right+left                 # M pontos
        z=B.z(u)
        for j,(x,y) in enumerate(ring): grid[i,j]=(x,y,z)
        info.append((cab,belt,top,bot,hw))
    # faces
    V=grid.reshape(-1,3)
    F=[]
    for i in range(Ns-1):
        for j in range(M):
            j2=(j+1)%M
            a=i*M+j;b=i*M+j2;c=(i+1)*M+j;e=(i+1)*M+j2
            F.append([a,b,c]);F.append([b,e,c])
    F=np.array(F)
    # normais suaves na grade inteira (orientadas para fora)
    N=vnormals(V,F)
    ctr=np.array([0,0.6,0])
    # garantir orientacao: normal apontando para fora do eixo central
    for i in range(Ns):
        c=grid[i].mean(axis=0)
        sl=slice(i*M,(i+1)*M)
        out=V[sl]-c
        flip=(np.sum(N[sl]*out,axis=1)<0)
    # checar sinal global
    test=np.sum(N*(V-np.array([0,0.6,0])*1),axis=1)
    if np.mean(test<0)>0.5: F=F[:,[0,2,1]];N=-N
    # arcos das rodas
    wh=[(d['FL'][2],d['R']),(d['RL'][2],d['R'])]
    Rarch=d['R']+arch_extra
    cx=V[F].mean(axis=1);fn=np.cross(V[F[:,1]]-V[F[:,0]],V[F[:,2]]-V[F[:,0]]);fl=np.linalg.norm(fn,axis=1,keepdims=True);fl[fl==0]=1;fn=fn/fl
    keep=np.ones(len(F),bool)
    for wz,r in wh:
        inside=((cx[:,2]-wz)**2+(cx[:,1]-r)**2<Rarch**2)&(np.abs(cx[:,0])>0.45*0.9)
        keep&=~inside
    # materiais
    cabv=np.array([info[min(int(f/M),Ns-1)][0] for f in (F[:,0]//1)])
    beltv=np.array([info[min(F[k,0]//M,Ns-1)][1] for k in range(len(F))])
    botv=np.array([info[min(F[k,0]//M,Ns-1)][3] for k in range(len(F))])
    hwv=np.array([info[min(F[k,0]//M,Ns-1)][4] for k in range(len(F))])
    glass=(cabv>0.25)&(cx[:,1]>beltv+0.02)&(fn[:,1]<0.80)&(np.abs(cx[:,0])<hwv*0.995)
    under=fn[:,1]<-0.45
    sill=(cx[:,1]<botv+0.085)&(np.abs(cx[:,0])>0.55*hwv)&(fn[:,1]<0.3) if sill_black else np.zeros(len(F),bool)
    trim=(under|sill)&keep&~glass
    carb=np.zeros(len(F),bool)
    uu=np.interp(cx[:,2],B._z,B._px)/(B.n-1)
    for (u0,u1,wf) in carbon:
        carb|=(uu>u0)&(uu<u1)&(np.abs(cx[:,0])<wf*hwv)&(fn[:,1]>0.55)
    carb&=~glass&~trim
    for name,msk in (('Glass',glass&keep),('Trim',trim),('Carbon',carb&keep),('Paint',keep&~glass&~trim&~carb)):
        if msk.any(): mb.add(name,V,F[msk],N)
    # tampas dianteira/traseira
    for i,idx in ((0,0),(Ns-1,1)):
        c=grid[i].mean(axis=0);vv=np.vstack([grid[i],[c]]);ff=[[M,k,(k+1)%M] if idx==0 else [M,(k+1)%M,k] for k in range(M)]
        if idx==0: ff=[[M,(k+1)%M,k] for k in range(M)]
        else: ff=[[M,k,(k+1)%M] for k in range(M)]
        mb.add('Paint',vv,ff,flat=True)
    B.grid=grid;B.info=info;B.us=us;B.M=M;B.Nh=Nh
    return B

def tire_mesh(R,wid,rim_r,sign=1,seg=40):
    mb=MB()
    prof=[(rim_r,0.50),(R-0.045,0.50),(R-0.012,0.44),(R,0.30),(R,-0.30),(R-0.012,-0.44),(R-0.045,-0.50),(rim_r,-0.50)]
    ang=np.linspace(0,2*np.pi,seg,endpoint=False)
    V=[];F=[]
    for r,x in prof:
        for a in ang: V.append([x*wid,r*math.cos(a),r*math.sin(a)])
    n=len(prof)
    for i in range(n-1):
        for j in range(seg):
            a=i*seg+j;b=i*seg+(j+1)%seg;c=(i+1)*seg+j;e=(i+1)*seg+(j+1)%seg
            F+=[[a,b,c],[b,e,c]]
    V=np.array(V);F=np.array(F)
    # orientacao para fora
    N=vnormals(V,F)
    if np.mean(np.sum(N*(V*[0,1,1]),axis=1)<0)>0.5: F=F[:,[0,2,1]]
    mb.add('Tire',V,F)
    return mb

def wheel_mesh(R,wid,style='multi',nsp=10,caliper=(0.8,0.03,0.03),rim_col=None,outward=1,rim_frac=0.74):
    """roda com eixo em X, face externa em +X; outward=-1 espelha"""
    mb=MB();rim_r=R*rim_frac
    mb.merge(tire_mesh(R,wid,rim_r))
    xo=wid*0.42;xi=-wid*0.45
    # barril
    mb.cyl('Rim',[xi,0,0],[xo,0,0],rim_r*0.985,seg=40,cap=False)
    mb.cyl('Trim',[xi*0.2,0,0],[xo*0.95,0,0],rim_r*0.80,seg=32,cap=True)
    # aro externo (labio)
    mb.cyl('Rim',[xo-0.012,0,0],[xo,0,0],rim_r*1.0,seg=40,cap=False)
    # raios
    for k in range(nsp):
        a=2*math.pi*k/nsp
        Rm=rotx(a)
        L=rim_r*0.92-0.05
        w0=0.040 if style=='multi' else 0.07
        mb.box('Rim',Rm@np.array([xo-0.012,0.05+L/2,0]),[0.022,L,w0],Rm)
        if style=='multi':  # raio duplo (V)
            Rm2=rotx(a+0.14)
            mb.box('Rim',Rm2@np.array([xo-0.02,0.05+L/2,0]),[0.018,L*0.95,0.022],Rm2)
    # cubo central com porca
    mb.cyl('Rim',[xo-0.03,0,0],[xo+0.012,0,0],0.052,seg=24)
    mb.cyl('Metal',[xo+0.012,0,0],[xo+0.03,0,0],0.028,seg=6)
    # disco de freio e pinca
    mb.cyl('Brake',[xo-0.17,0,0],[xo-0.20,0,0],R*0.66,seg=40)
    mb.cyl('Trim',[xo-0.17,0,0],[xo-0.2,0,0],R*0.30,seg=24)
    # pinca na parte de cima-traseira
    Rc=rotx(math.radians(-35))
    mb.box('Caliper',Rc@np.array([xo-0.185,R*0.55,0]),[0.075,R*0.30,R*0.42],Rc)
    out=MB();out.merge(mb,mirror_x=(outward<0))
    if caliper:
        for d in out.m.get('Caliper',[]) if False else []: pass
    return out
