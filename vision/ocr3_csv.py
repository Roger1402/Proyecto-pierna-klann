import numpy as np,pandas as pd
L=np.load('lab.npy');n=-1
m1=[2,1,0,1,2,3];m2=[n,3,1,2,6,9,0,7,4,8,8,7,5,1,0,9,2,5];m3=[7,8,n,4,1,2,8,0,3,1,9,6,5,6,5,5,1,9]
a,b,c=np.array(m1)[L[0]],np.array(m2)[L[1]],np.array(m3)[L[2]]
v=np.where((b<0)|(c<0),np.nan,(a*100+b*10+c)/1000.); t=(np.arange(len(v))+1085)/59.9447
R=[]
for k in range(182,958):
    s=v[(t>=k/10-.05)&(t<k/10+.05)]; s=s[np.isfinite(s)]
    if len(s)==0: R.append((k/10,np.nan,0));continue
    u,q=np.unique(s,return_counts=True); R.append((k/10,u[q.argmax()],q.max()/6))
d=pd.DataFrame(R,columns=['t_video_s','I_fuente_A','conf'])
for T,e in [(19,.182),(20,.19),(22,.181),(24,.184),(27,.159),(30,.182),(35,.186),(45,.214),(50,.18),(55,.213),(60,.207),(65,.165),(70,.275),(75,.305),(80,.245),(85,.197),(90,.218),(92,.011)]:
    print(T,e,d.I_fuente_A[(d.t_video_s-T).abs()<.06].tolist(),end='; ')
d.loc[d.conf<.3,'I_fuente_A']=np.nan
print(d.I_fuente_A.isna().sum(),len(d)); r=d[(d.t_video_s>20)&(d.t_video_s<90.5)]; print(r.I_fuente_A.describe())
print(d[d.t_video_s>91.5].I_fuente_A.describe())
d['t_enc_s']=(d.t_video_s-10.30).round(2)
print(r[r.I_fuente_A<.09]); print(d.head(12))
d.round(3).to_csv(r'C:/Users/Roger/Documents/MATLAB/ProyectoKlann/datos/corriente_display.csv',index=False)
# media por fase
e=pd.read_csv('C:/Users/Roger/Downloads/klann_r20_pwm100_20261124_130754.csv')
cu=np.interp(r.t_enc_s if 't_enc_s' in r else r.t_video_s-10.3,e.t_s,-e.cuentas+e.cuentas.iloc[0])%3950.3/3950.3*360
r=r.assign(f=cu//15*15); print(r.groupby('f').I_fuente_A.agg(['mean','std','count']).round(3).T.to_string())
