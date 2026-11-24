import numpy as np, cv2, json
from scipy import ndimage as ndi
SPECS={
 'gt3rs':dict(f='25705.jpg',side=(150,245,950,462),top=(148,700,971,1016),L=4.572,thr=70),
 'sf90':dict(f='25637.png',side=(140,296,1190,556),top=(176,832,1190,1236),L=4.704,thr=70),
 'valkyrie':dict(f='25645.jpg',side=(28,576,748,756),top=(30,791,750,1080),L=4.54,thr=70),
}
def mask_of(im,box,thr):
    x0,y0,x1,y1=box
    c=im[y0:y1,x0:x1].astype(int)
    d=np.abs(c-255).sum(axis=2)
    m=d>thr
    m=ndi.binary_closing(m,iterations=2)
    m=ndi.binary_fill_holes(m)
    lab,n=ndi.label(m)
    if n>1:
        sz=ndi.sum(m,lab,range(1,n+1)); m=lab==(1+int(np.argmax(sz)))
    return m
if __name__=='__main__':
    for k,s in SPECS.items():
        im=cv2.imread('/mnt/user-data/uploads/'+s['f'])
        ms=mask_of(im,s['side'],s['thr']); mt=mask_of(im,s['top'],s['thr'])
        cv2.imwrite(f'mask_{k}_side.png',(ms*255).astype(np.uint8)); cv2.imwrite(f'mask_{k}_top.png',(mt*255).astype(np.uint8))
        print(k,ms.shape,mt.shape)
