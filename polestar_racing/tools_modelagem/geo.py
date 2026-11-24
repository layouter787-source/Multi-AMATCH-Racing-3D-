import numpy as np, json, struct, math

MATS={
 'Paint':dict(c=[0.92,0.92,0.94,1],m=0.45,r=0.22),
 'Glass':dict(c=[0.02,0.03,0.04,0.55],m=0.0,r=0.05,blend=True),
 'Tire':dict(c=[0.03,0.03,0.03,1],m=0.0,r=0.9),
 'Rim':dict(c=[0.42,0.40,0.38,1],m=0.9,r=0.3),
 'Brake':dict(c=[0.12,0.12,0.13,1],m=0.6,r=0.5),
 'Caliper':dict(c=[0.8,0.03,0.03,1],m=0.3,r=0.4),
 'Trim':dict(c=[0.02,0.02,0.02,1],m=0.0,r=0.5),
 'Carbon':dict(c=[0.04,0.04,0.045,1],m=0.5,r=0.3),
 'Headlight':dict(c=[1,1,0.95,1],m=0.0,r=0.1,e=[1,1,0.9]),
 'Taillight':dict(c=[0.8,0.02,0.02,1],m=0.0,r=0.2,e=[1,0.03,0.03]),
 'Metal':dict(c=[0.6,0.6,0.62,1],m=0.9,r=0.3),
}

def rotx(a): c,s=math.cos(a),math.sin(a); return np.array([[1,0,0],[0,c,-s],[0,s,c]])
def roty(a): c,s=math.cos(a),math.sin(a); return np.array([[c,0,s],[0,1,0],[-s,0,c]])
def rotz(a): c,s=math.cos(a),math.sin(a); return np.array([[c,-s,0],[s,c,0],[0,0,1]])

def vnormals(V,F):
    n=np.zeros_like(V)
    a,b,c=V[F[:,0]],V[F[:,1]],V[F[:,2]]
    fn=np.cross(b-a,c-a)
    for k in range(3): np.add.at(n,F[:,k],fn)
    l=np.linalg.norm(n,axis=1,keepdims=True); l[l==0]=1
    return n/l

class MB:
    def __init__(s): s.m={}
    def add(s,mat,V,F,N=None,flat=False):
        V=np.asarray(V,float);F=np.asarray(F,int)
        if len(F)==0: return
        if flat:
            V2=V[F.reshape(-1)];F2=np.arange(len(V2)).reshape(-1,3);V,F=V2,F2
        if N is None: N=vnormals(V,F)
        d=s.m.setdefault(mat,{'V':[],'N':[],'F':[],'o':0})
        d['V'].append(V);d['N'].append(N);d['F'].append(F+d['o']);d['o']+=len(V)
    def box(s,mat,c,size,R=None):
        h=np.array(size)/2
        V=np.array([[-1,-1,-1],[1,-1,-1],[1,1,-1],[-1,1,-1],[-1,-1,1],[1,-1,1],[1,1,1],[-1,1,1]])*h
        F=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,4,7],[0,7,3],[1,2,6],[1,6,5],[3,7,6],[3,6,2],[0,1,5],[0,5,4]]
        if R is not None: V=V@np.asarray(R).T
        s.add(mat,V+np.asarray(c),F,flat=True)
    def cyl(s,mat,p0,p1,r0,r1=None,seg=20,cap=True):
        p0=np.asarray(p0,float);p1=np.asarray(p1,float);r1=r0 if r1 is None else r1
        ax=p1-p0;L=np.linalg.norm(ax);ax/=L
        t=np.array([0,1,0]) if abs(ax[1])<0.9 else np.array([1,0,0])
        u=np.cross(ax,t);u/=np.linalg.norm(u);w=np.cross(ax,u)
        ang=np.linspace(0,2*np.pi,seg,endpoint=False)
        ring=np.outer(np.cos(ang),u)+np.outer(np.sin(ang),w)
        V=np.vstack([p0+ring*r0,p1+ring*r1]);F=[]
        for i in range(seg):
            j=(i+1)%seg;F+=[[i,j,seg+j],[i,seg+j,seg+i]]
        N=vnormals(V,np.array(F))
        s.add(mat,V,F,N)
        if cap:
            for p,rr,sg in ((p0,r0,-1),(p1,r1,1)):
                vv=np.vstack([p+ring*rr,[p]]);ff=[[seg,i,(i+1)%seg] if sg>0 else [seg,(i+1)%seg,i] for i in range(seg)]
                s.add(mat,vv,ff,flat=True)
    def ell(s,mat,c,rad,R=None,seg=16,rings=10):
        th=np.linspace(0,np.pi,rings+1);ph=np.linspace(0,2*np.pi,seg,endpoint=False)
        V=[];
        for t in th:
            for p in ph: V.append([np.sin(t)*np.cos(p),np.cos(t),np.sin(t)*np.sin(p)])
        V=np.array(V);F=[]
        for i in range(rings):
            for j in range(seg):
                ia=i*seg+j;ib=i*seg+(j+1)%seg;ic=(i+1)*seg+j;idd=(i+1)*seg+(j+1)%seg
                F+=[[ia,ic,ib],[ib,ic,idd]]
        N=V.copy()
        V=V*np.asarray(rad)
        if R is not None: V=V@np.asarray(R).T;N=N@np.asarray(R).T
        s.add(mat,V+np.asarray(c),F,N)
    def extrude(s,mat,poly,z0,z1,axis='z'):
        """poly: lista (x,y) fechada CCW no plano XY, extrude ao longo de Z"""
        poly=np.asarray(poly,float);n=len(poly)
        V=[];F=[]
        for i in range(n):
            a=poly[i];b=poly[(i+1)%n]
            base=len(V)
            V+=[[a[0],a[1],z0],[b[0],b[1],z0],[b[0],b[1],z1],[a[0],a[1],z1]]
            F+=[[base,base+1,base+2],[base,base+2,base+3]]
        # tampas (fan simples a partir do centroide)
        c=poly.mean(axis=0)
        for z,sg in ((z0,-1),(z1,1)):
            base=len(V);V.append([c[0],c[1],z])
            for i in range(n):
                V.append([poly[i][0],poly[i][1],z])
            for i in range(n):
                a=base+1+i;b=base+1+(i+1)%n
                F.append([base,a,b] if sg>0 else [base,b,a])
        V=np.array(V);F=np.array(F)
        if axis=='x': V=V[:,[2,1,0]];F=F[:,[0,2,1]]
        s.add(mat,V,F,flat=True)
    def inverted(s):
        o=MB()
        for k,d in s.m.items():
            o.add(k,np.vstack(d['V']),np.vstack(d['F'])[:,[0,2,1]],-np.vstack(d['N']))
        return o
    def merge(s,o,T=None,mirror_x=False):
        for k,d in o.m.items():
            V=np.vstack(d['V']);N=np.vstack(d['N']);F=np.vstack(d['F'])
            if mirror_x:
                V=V*[-1,1,1];N=N*[-1,1,1];F=F[:,[0,2,1]]
            s.add(k,V,F,N)

def write_glb(path,nodes_spec,meshes,mat_override=None):
    """nodes_spec: lista de dict(name,mesh(MB)|None,translation,children[names])  - primeiro = raiz"""
    mats_used=[];mat_idx={}
    for mb in meshes.values():
        for k in mb.m:
            if k not in mat_idx: mat_idx[k]=len(mats_used);mats_used.append(k)
    binb=bytearray();bvs=[];accs=[];gm=[];mesh_idx={}
    def pad():
        while len(binb)%4: binb.append(0)
    for name,mb in meshes.items():
        prims=[]
        for k,d in mb.m.items():
            V=np.vstack(d['V']).astype(np.float32);N=np.vstack(d['N']).astype(np.float32);F=np.vstack(d['F']).astype(np.uint32)
            ids=[]
            for arr,tgt in ((V,34962),(N,34962),(F.reshape(-1),34963)):
                pad();off=len(binb);binb.extend(arr.tobytes())
                bvs.append(dict(buffer=0,byteOffset=off,byteLength=arr.nbytes,target=tgt))
                ids.append(len(bvs)-1)
            accs.append(dict(bufferView=ids[0],componentType=5126,count=len(V),type='VEC3',min=V.min(0).tolist(),max=V.max(0).tolist()))
            accs.append(dict(bufferView=ids[1],componentType=5126,count=len(N),type='VEC3'))
            accs.append(dict(bufferView=ids[2],componentType=5125,count=int(F.size),type='SCALAR'))
            a=len(accs)
            prims.append(dict(attributes=dict(POSITION=a-3,NORMAL=a-2),indices=a-1,material=mat_idx[k]))
        mesh_idx[name]=len(gm);gm.append(dict(name=name,primitives=prims))
    gmats=[]
    for k in mats_used:
        d=dict(MATS[k]) if mat_override is None or k not in mat_override else mat_override[k]
        g=dict(name=k,pbrMetallicRoughness=dict(baseColorFactor=d['c'],metallicFactor=d['m'],roughnessFactor=d['r']))
        if 'e' in d: g['emissiveFactor']=d['e']
        if d.get('blend'): g['alphaMode']='BLEND';g['doubleSided']=True
        gmats.append(g)
    names=[n['name'] for n in nodes_spec]
    gn=[]
    for n in nodes_spec:
        d=dict(name=n['name'])
        if n.get('mesh'): d['mesh']=mesh_idx[n['mesh']]
        if n.get('translation'): d['translation']=list(map(float,n['translation']))
        if n.get('children'): d['children']=[names.index(c) for c in n['children']]
        gn.append(d)
    pad()
    j=dict(asset=dict(version='2.0',generator='polestar-gen'),scene=0,scenes=[dict(nodes=[0])],nodes=gn,meshes=gm,materials=gmats,accessors=accs,bufferViews=bvs,buffers=[dict(byteLength=len(binb))])
    js=json.dumps(j).encode()
    while len(js)%4: js+=b' '
    out=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(binb))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(binb),0x004E4942)+bytes(binb)
    open(path,'wb').write(out)
