import numpy as np, json, struct, os
from make_car import build, CFG
from geo import *
OUT='/home/claude/proj/polestar_racing/cars/'
for key in CFG:
    d,B,mb,wh=build(key)
    meshes={'Body':mb}
    nodes=[dict(name='Car',children=['Body','Wheel_FL_Steer','Wheel_FR_Steer','Wheel_RL','Wheel_RR']),dict(name='Body',mesh='Body')]
    for k in ('FL','FR'):
        meshes['W'+k]=wh[k]
        nodes.append(dict(name=f'Wheel_{k}_Steer',translation=[0,d['R'],d['FL'][2]],children=[f'Wheel_{k}']))
        nodes.append(dict(name=f'Wheel_{k}',mesh='W'+k))
    for k in ('RL','RR'):
        meshes['W'+k]=wh[k];x=d['RL'][0] if k=='RL' else -d['RL'][0]
        nodes.append(dict(name=f'Wheel_{k}',mesh='W'+k,translation=[x,d['R'],d['RL'][2]]))
    # FR x positivo; RR x positivo
    for n in nodes:
        if n['name']=='Wheel_FR_Steer': n['translation'][0]=abs(d['FL'][0])
        if n['name']=='Wheel_FL_Steer': n['translation'][0]=-abs(d['FL'][0])
        if n['name']=='Wheel_RL': n['translation'][0]=-abs(d['RL'][0])
        if n['name']=='Wheel_RR': n['translation'][0]=abs(d['RL'][0])
    write_glb(OUT+key+'.glb',nodes,meshes)
    tris=sum(len(f) for m in meshes.values() for v in m.m.values() for f in v['F'])
    print(key,os.path.getsize(OUT+key+'.glb')//1024,'KB',tris,'tris')
