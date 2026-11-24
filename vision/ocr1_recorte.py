import cv2,numpy as np
c=cv2.VideoCapture('C:/Users/Roger/Downloads/Videos Klann/video_movimeinto.mp4');A=[];n=0
while 1:
    ok,im=c.read()
    if not ok:break
    A.append(cv2.cvtColor(im[150:164,655:686],cv2.COLOR_BGR2GRAY)); n+=1
A=np.array(A).astype(np.float32); np.save('A.npy',A); print(A.shape)
d=np.abs(A[1:]-A[:-1]).mean((1,2)); s=d[1100:5400]; print(np.percentile(s,[10,50,80,90,95,99]))
ch=np.where(s>np.percentile(s,93))[0]; print(np.diff(ch)[:80])
m=A[1100:5400].mean(0); s=A[1100:5400].std(0)
cv2.imwrite('m.png',cv2.resize(np.hstack([m,s*4]).clip(0,255).astype(np.uint8),None,fx=16,fy=16,interpolation=cv2.INTER_CUBIC))
o=[cv2.resize(A[i:i+3].mean(0),None,fx=8,fy=8,interpolation=cv2.INTER_CUBIC) for i in range(1500,1500+12*8,8)]
cv2.imwrite('m2.png',np.vstack([np.hstack(o[k:k+4]) for k in range(0,12,4)]).clip(0,255))
