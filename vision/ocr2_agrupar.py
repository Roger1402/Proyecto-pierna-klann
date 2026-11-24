import cv2,numpy as np
A=np.load('A.npy')[1085:]
cols=[(10,15),(15,20),(19,25)] # x en px (de m.png /16: d1 10.5-14, d2 15-19, d3 20-24)
cv2.setRNGSeed(1);rows=[];np_c=[]
for a,b in cols:
    X=A[:,2:11,a:b].reshape(len(A),-1); X=X-X.mean(1,keepdims=True); X=X.astype(np.float32)
    K=6 if a==10 else 18
    _,lab,cen=cv2.kmeans(X,K,None,(3,100,.01),8,cv2.KMEANS_PP_CENTERS); lab=lab.ravel()
    np_c.append(lab); ims=[]
    for k in range(18):
        if k<K:
            q=A[lab==k].mean(0)[1:12,8:26]; z=cv2.resize(q,None,fx=8,fy=8,interpolation=cv2.INTER_CUBIC)
            f=q.copy(); z=np.ascontiguousarray(np.clip(z,0,255).astype(np.uint8)); cv2.putText(z,f'{k}:{(lab==k).sum()}',(2,10),0,.35,255,1)
            x0,x1=(a-8)*8,(b-8)*8; cv2.rectangle(z,(x0,0),(x1,86),255,1)
        else: z=np.zeros((88,144))
        ims.append(z)
    for j in (0,9): rows.append(np.hstack(ims[j:j+9]))
np.save('lab.npy',np.array(np_c)); cv2.imwrite('k.png',np.vstack(rows).astype(np.uint8))
