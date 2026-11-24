import json,struct,numpy as np
def load(p):
    d=open(p,'rb').read()
    l=struct.unpack('<I',d[12:16])[0];j=json.loads(d[20:20+l])
    off=20+l;bl=struct.unpack('<I',d[off:off+4])[0];binc=d[off+8:off+8+bl]
    return j,binc
def local_mat(n):
    if 'matrix' in n: return np.array(n['matrix']).reshape(4,4).T
    t=np.array(n.get('translation',[0,0,0]));q=n.get('rotation',[0,0,0,1]);s=np.array(n.get('scale',[1,1,1]))
    x,y,z,w=q
    R=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    M=np.eye(4);M[:3,:3]=R*s;M[:3,3]=t;return M
def walk(j):
    nodes=j['nodes'];par={}
    for i,n in enumerate(nodes):
        for c in n.get('children',[]): par[c]=i
    world={}
    def W(i):
        if i in world: return world[i]
        m=local_mat(nodes[i]);world[i]=(W(par[i])@m) if i in par else m;return world[i]
    for i in range(len(nodes)): W(i)
    return world,par
def mesh_aabb(j,mi):
    lo=np.array([1e18]*3);hi=-lo
    for pr in j['meshes'][mi]['primitives']:
        a=j['accessors'][pr['attributes']['POSITION']]
        lo=np.minimum(lo,a['min']);hi=np.maximum(hi,a['max'])
    return lo,hi
def world_aabb(j,world,i):
    n=j['nodes'][i]
    if 'mesh' not in n: return None
    lo,hi=mesh_aabb(j,n['mesh']);M=world[i]
    cs=np.array([[x,y,z,1] for x in(lo[0],hi[0]) for y in(lo[1],hi[1]) for z in(lo[2],hi[2])])@M.T
    return cs[:,:3].min(0),cs[:,:3].max(0)

CT={5120:np.int8,5121:np.uint8,5122:np.int16,5123:np.uint16,5125:np.uint32,5126:np.float32}
NC={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
def read_acc(j,binc,ai):
    a=j['accessors'][ai]
    if 'bufferView' not in a: return np.zeros((a['count'],NC[a['type']]),CT[a['componentType']])
    bv=j['bufferViews'][a['bufferView']];n=NC[a['type']];dt=np.dtype(CT[a['componentType']])
    off=bv.get('byteOffset',0)+a.get('byteOffset',0);stride=bv.get('byteStride',n*dt.itemsize)
    cnt=a['count']
    if stride==n*dt.itemsize:
        arr=np.frombuffer(binc,dtype=dt,count=cnt*n,offset=off).reshape(cnt,n)
    else:
        arr=np.zeros((cnt,n),dt)
        for i in range(cnt): arr[i]=np.frombuffer(binc,dtype=dt,count=n,offset=off+i*stride)
    if a.get('normalized'):
        info=np.iinfo(dt);arr=np.maximum(arr.astype(np.float32)/info.max,-1.0)
    return arr
def flatten(j,binc):
    """-> lista de dict(mat=int,P,N,UV,UV2,F) em coordenadas de mundo"""
    world,par=walk(j);out=[]
    for ni,n in enumerate(j['nodes']):
        if 'mesh' not in n: continue
        M=world[ni];R=M[:3,:3];nm=np.linalg.inv(R).T
        for pr in j['meshes'][n['mesh']]['primitives']:
            if pr.get('mode',4)!=4: continue
            at=pr['attributes'];P=read_acc(j,binc,at['POSITION']).astype(np.float64)
            P=P@R.T+M[:3,3]
            N=read_acc(j,binc,at['NORMAL']).astype(np.float64)@nm.T if 'NORMAL' in at else None
            if N is not None:
                l=np.linalg.norm(N,axis=1,keepdims=True);l[l==0]=1;N=N/l
            UV=read_acc(j,binc,at['TEXCOORD_0']).astype(np.float32) if 'TEXCOORD_0' in at else None
            UV2=read_acc(j,binc,at['TEXCOORD_1']).astype(np.float32) if 'TEXCOORD_1' in at else None
            F=read_acc(j,binc,pr['indices']).reshape(-1,3).astype(np.int64) if 'indices' in pr else np.arange(len(P)).reshape(-1,3)
            if np.linalg.det(R)<0: F=F[:,[0,2,1]]
            out.append(dict(mat=pr.get('material',-1),P=P,N=N,UV=UV,UV2=UV2,F=F,node=ni,name=n.get('name','')))
    return out
