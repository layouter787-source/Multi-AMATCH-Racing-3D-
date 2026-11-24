import sys,re,json,struct,copy,math
sys.path.insert(0,'/home/claude/glb')
from glbtools import *
import cv2
from scipy.cluster.vq import kmeans2

CARS={
 'gt3rs':dict(src='porsche_gt3_rs',tire=['Scene_-_Root.002'],scale=1.0,paint=r'carPaint',paint_min_lum=0.3,tail=r'brakelight|led_lights\.002',front_sign=1,yaw_fix=False,static=r'cal+ip|glass|carPaint|plastic_mgl|rubbertrim'),
 'sf90':dict(src='2023_ferrari_sf90_xx_stradale',tire=['Wheel1A'],scale=97.3,paint=r'Paint_Material',paint_min_lum=0.0,tail=r'RED_GLASS',front_sign=1,yaw_fix=False,static=r'cal+ip|glass|Paint_Material|Window'),
 'valkyrie':dict(src='2021__aston_martin_valkyrie',tire=['4k_tire'],scale=1.0,paint=r'^body2$',paint_min_lum=0.0,tail=r'red_zad_fara',front_sign=1,yaw_fix=False,static=r'cal+ip|Caliper|glass|^body'),
 'veneno':dict(src='lamborghini_venevo',tire=['wheel'],scale=0.28,paint=r'^material_20$',paint_min_lum=0.0,tail=r'^Vt_Liu\.001$',front_sign=1,yaw_fix=True,static=r'cal+ip|glass|material_20|material_14'),
 'onceleven':dict(src='mercedes_benz_vision_one_eleven',tire=['tire_street'],scale=1.0,paint=r'carpaint',paint_min_lum=0.0,tail=r'detail_led_brake',front_sign=1,yaw_fix=False,static=r'cal+ip|glass|carpaint'),
}
def lum(m):
    c=m.get('pbrMetallicRoughness',{}).get('baseColorFactor',[1,1,1,1]);return 0.3*c[0]+0.59*c[1]+0.11*c[2]

def convert(key,out_path,max_tex=1024):
    cf=CARS[key];j,binc=load(f'/mnt/user-data/uploads/{cf["src"]}.glb');mats=j['materials']
    prims=flatten(j,binc)
    mname=lambda mi:mats[mi].get('name','') if mi>=0 else ''
    # --- pneus -> 4 rodas (kmeans)
    T=np.vstack([q['P'] for q in prims if any(s in mname(q['mat']) for s in cf['tire'])])
    cen,lab=kmeans2(T[:,[0,2]],4,minit='++',seed=3)
    W=[]
    for ci in range(4):
        P=T[lab==ci];lo,hi=P.min(0),P.max(0);W.append(dict(c=(lo+hi)/2,s=hi-lo))
    # yaw (so se necessario): eixo longitudinal pelos centros
    yaw=0.0
    if cf['yaw_fix']:
        med=np.median([v['c'][0] for v in W]);left=[w for w in W if w['c'][0]<med];right=[w for w in W if w['c'][0]>=med]
        ang=[]
        for side in (left,right):
            a,b=sorted(side,key=lambda w:w['c'][2]);d=b['c']-a['c'];ang.append(math.atan2(d[0],d[2]))
        yaw=float(np.mean(ang))
    phi=-yaw;Ry=np.array([[math.cos(phi),0,math.sin(phi)],[0,1,0],[-math.sin(phi),0,math.cos(phi)]])
    flip=np.diag([-1,1,-1.0])         # frente +Z -> -Z
    M3=cf['scale']*(flip@Ry)
    tf=lambda P:P@M3.T
    for q in prims:
        q['P']=tf(q['P'])
        if q['N'] is not None:
            q['N']=q['N']@(flip@Ry).T
    for w in W:
        w['c']=M3@w['c'];w['s']=np.abs(M3)@w['s']
    # classificar: frente = z negativo apos o flip
    W.sort(key=lambda w:(w['c'][2],w['c'][0]))
    front=W[:2];rear=W[2:]
    front.sort(key=lambda w:w['c'][0]);rear.sort(key=lambda w:w['c'][0])
    corners={'FL':front[0],'FR':front[1],'RL':rear[0],'RR':rear[1]}
    xm=np.mean([w['c'][0] for w in W]);zm=np.mean([w['c'][2] for w in W])
    Rf=np.mean([max(w['s'][1],w['s'][2])/2 for w in front]);Rr=np.mean([max(w['s'][1],w['s'][2])/2 for w in rear])
    ymin=np.mean([w['c'][1]-max(w['s'][1],w['s'][2])/2 for w in W])
    shift=np.array([-xm,-ymin,-zm])
    for q in prims: q['P']=q['P']+shift
    for w in W: w['c']=w['c']+shift;w['R']=max(w['s'][1],w['s'][2])/2;w['w']=w['s'][0]
    # --- separar triangulos das rodas
    static=re.compile(cf['static'],re.I)
    body={};wheels={k:{} for k in corners}
    def put(d,q,sel,mi):
        F=q['F'][sel]
        if len(F)==0: return
        ent=d.setdefault(mi,[]);ent.append((q,F))
    for q in prims:
        mi=q['mat'];nm=mname(mi)
        cent=q['P'][q['F']].mean(axis=1)
        taken=np.zeros(len(q['F']),bool)
        if not static.search(nm):
            for k,w in corners.items():
                dx=np.abs(cent[:,0]-w['c'][0]);dr=np.hypot(cent[:,1]-w['c'][1],cent[:,2]-w['c'][2])
                sel=(dx<=w['w']/2+0.03)&(dr<=w['R']*1.02)&(~taken)
                put(wheels[k],q,sel,mi);taken|=sel
        put(body,q,~taken,mi)
    # --- materiais
    mats=copy.deepcopy(mats)
    paint_re=re.compile(cf['paint']);tail_re=re.compile(cf['tail'])
    for i,m in enumerate(mats):
        nm=m.get('name','')
        pbr=m.setdefault('pbrMetallicRoughness',{})
        if paint_re.search(nm) and lum(m)>=cf['paint_min_lum']:
            m['name']='Paint';pbr.pop('baseColorTexture',None);pbr['baseColorFactor']=[1,1,1,1];pbr['metallicFactor']=0.55;pbr['roughnessFactor']=0.28
            m.pop('alphaMode',None);m.pop('normalTexture',None);m.pop('occlusionTexture',None)
        elif tail_re.search(nm):
            m['name']='Taillight';m['emissiveFactor']=[1.0,0.03,0.03];m.pop('emissiveTexture',None)
            pbr['baseColorFactor']=[0.8,0.02,0.02,1];pbr.pop('baseColorTexture',None)
            m.pop('alphaMode',None)
        elif re.search('glass|window',nm,re.I) and m.get('alphaMode')=='BLEND':
            m['name']='Glass'
        if 'extensions' in m:
            m['extensions'].pop('KHR_materials_transmission',None)
            if not m['extensions']: m.pop('extensions')
        m['doubleSided']=m.get('doubleSided',False)
    first={};remap={}
    for i,m in enumerate(mats):
        nm=m.get('name','')
        if nm in('Paint','Taillight','Glass'):
            if nm in first: remap[i]=first[nm]
            else: first[nm]=i
    def merge_groups(g):
        out={}
        for mi,ent in g.items():
            out.setdefault(remap.get(mi,mi),[]).extend(ent)
        return out
    body=merge_groups(body)
    for k in wheels: wheels[k]=merge_groups(wheels[k])
    # --- imagens: reduzir
    newbin=bytearray();bvs=[];images=[]
    def pad():
        while len(newbin)%4: newbin.append(0)
    for im in j.get('images',[]):
        bv=j['bufferViews'][im['bufferView']];raw=binc[bv.get('byteOffset',0):bv.get('byteOffset',0)+bv['byteLength']]
        arr=cv2.imdecode(np.frombuffer(raw,np.uint8),cv2.IMREAD_UNCHANGED)
        mime=im.get('mimeType','image/jpeg');data=raw
        if arr is not None:
            h,w=arr.shape[:2];sc=min(1.0,max_tex/max(h,w))
            if sc<1.0: arr=cv2.resize(arr,(int(w*sc),int(h*sc)),interpolation=cv2.INTER_AREA)
            has_a=arr.ndim==3 and arr.shape[2]==4 and arr[:,:,3].min()<250
            if has_a:
                ok,enc=cv2.imencode('.png',arr);mime='image/png'
            else:
                a3=arr[:,:,:3] if arr.ndim==3 else arr
                ok,enc=cv2.imencode('.jpg',a3,[cv2.IMWRITE_JPEG_QUALITY,86]);mime='image/jpeg'
            if ok: data=enc.tobytes()
        pad();off=len(newbin);newbin.extend(data);bvs.append(dict(buffer=0,byteOffset=off,byteLength=len(data)))
        images.append(dict(bufferView=len(bvs)-1,mimeType=mime))
    # --- escrever geometria
    accs=[];meshes=[]
    def emit(groups,name):
        prs=[]
        for mi,ent in groups.items():
            Ps=[];Ns=[];Us=[];U2=[];Fs=[];o=0;hasU2=any(q['UV2'] is not None for q,_ in ent)
            for q,F in ent:
                used=np.unique(F);remap=np.full(len(q['P']),-1,np.int64);remap[used]=np.arange(len(used))
                Ps.append(q['P'][used]);n=len(used)
                Ns.append(q['N'][used] if q['N'] is not None else np.tile([0,1,0.0],(n,1)))
                Us.append(q['UV'][used] if q['UV'] is not None else np.zeros((n,2),np.float32))
                U2.append(q['UV2'][used] if q['UV2'] is not None else np.zeros((n,2),np.float32))
                Fs.append(remap[F]+o);o+=n
            P=np.vstack(Ps).astype(np.float32);N=np.vstack(Ns).astype(np.float32);UV=np.vstack(Us).astype(np.float32);F=np.vstack(Fs).astype(np.uint32)
            at={}
            def add(arr,typ,comp,tgt,nm,mm=False):
                pad();off=len(newbin);newbin.extend(arr.tobytes())
                bvs.append(dict(buffer=0,byteOffset=off,byteLength=arr.nbytes,target=tgt))
                a=dict(bufferView=len(bvs)-1,componentType=comp,count=len(arr) if tgt==34962 else int(arr.size),type=typ)
                if mm: a['min']=arr.min(0).tolist();a['max']=arr.max(0).tolist()
                accs.append(a);return len(accs)-1
            at['POSITION']=add(P,'VEC3',5126,34962,'p',True);at['NORMAL']=add(N,'VEC3',5126,34962,'n')
            at['TEXCOORD_0']=add(UV,'VEC2',5126,34962,'u')
            if hasU2: at['TEXCOORD_1']=add(np.vstack(U2).astype(np.float32),'VEC2',5126,34962,'u2')
            idx=add(F.reshape(-1),'SCALAR',5125,34963,'i')
            pr=dict(attributes=at,indices=idx)
            if mi>=0: pr['material']=mi
            prs.append(pr)
        meshes.append(dict(name=name,primitives=prs));return len(meshes)-1
    nodes=[dict(name='Car',children=[1])]
    nodes.append(dict(name='Body',mesh=emit(body,'Body')))
    for k in ('FL','FR','RL','RR'):
        w=corners[k];ent=wheels[k]
        # recentrar roda na origem
        for lst in ent.values():
            for q,F in lst:
                if not q.get('_c_'+k): pass
        sub={}
        for mi,lst in ent.items():
            newl=[]
            for q,F in lst:
                q2=dict(q);q2['P']=q['P']-w['c'];newl.append((q2,F))
            sub[mi]=newl
        mi_=emit(sub,'W'+k)
        nodes[0]['children'].append(len(nodes))
        if k[0]=='F':
            nodes.append(dict(name=f'Wheel_{k}_Steer',translation=[float(v) for v in w['c']],children=[len(nodes)+1]))
            nodes.append(dict(name=f'Wheel_{k}',mesh=mi_))
        else:
            nodes.append(dict(name=f'Wheel_{k}',mesh=mi_,translation=[float(v) for v in w['c']]))
    out=dict(asset=dict(version='2.0',generator='polestar-convert'),scene=0,scenes=[dict(nodes=[0])],nodes=nodes,meshes=meshes,materials=mats,
        accessors=accs,bufferViews=bvs,buffers=[dict(byteLength=0)])
    if images: out['images']=images
    for kk in ('textures','samplers'):
        if kk in j: out[kk]=j[kk]
    exts=[e for e in j.get('extensionsUsed',[]) if e!='KHR_materials_transmission']
    if exts: out['extensionsUsed']=exts
    pad();out['buffers'][0]['byteLength']=len(newbin)
    js=json.dumps(out).encode()
    while len(js)%4: js+=b' '
    blob=struct.pack('<III',0x46546C67,2,12+8+len(js)+8+len(newbin))+struct.pack('<II',len(js),0x4E4F534A)+js+struct.pack('<II',len(newbin),0x004E4942)+bytes(newbin)
    open(out_path,'wb').write(blob)
    # --- info para cars_data
    allv=np.vstack([q['P'] for q in prims])
    paint_v=np.vstack([q['P'] for q in prims if mats[q['mat']].get('name') in('Paint',)]) if any(mats[q['mat']].get('name')=='Paint' for q in prims) else allv
    glass_v=[q['P'] for q in prims if mats[q['mat']].get('name')=='Glass']
    info=dict(R_front=float(Rf),R_rear=float(Rr),wheel_w=[float(corners['FL']['w']),float(corners['RL']['w'])],
      wheels={k:[float(v) for v in corners[k]['c']] for k in corners},
      zmin=float(allv[:,2].min()),zmax=float(allv[:,2].max()),height=float(np.percentile(allv[:,1],99.7)),
      width=float(2*np.percentile(np.abs(paint_v[:,0]),99.0)),
      glass_z=[float(np.vstack(glass_v)[:,2].min()),float(np.vstack(glass_v)[:,2].max())] if glass_v else None,
      glass_y=float(np.vstack(glass_v)[:,1].max()) if glass_v else None,
      tris=int(sum(len(q['F']) for q in prims)),yaw_deg=math.degrees(yaw))
    return info,prims,corners,body
if __name__=='__main__':
    import os;os.makedirs('/home/claude/glb/out',exist_ok=True)
    k=sys.argv[1]
    info,_,_,_=convert(k,f'/home/claude/glb/out/{k}.glb')
    print(k,json.dumps(info,indent=1),os.path.getsize(f'/home/claude/glb/out/{k}.glb')//1024,'KB')
