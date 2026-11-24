import sys; sys.path.insert(0,'cad')
import klann_geom as kg, klann_parts as kp
from build123d import *
A,B,C=kg.GROUND["A"],kg.GROUND["B"],kg.P0["C"]
P={n:kp.placement(k)*f() for n,k,f in [('engranaje','engranaje',kp.engranaje_manivela),('pinon','pinon',kp.pinon),('biela','biela',kp.biela),('balancin_superior','balancin_superior',kp.balancin_superior),('balancin_inferior','balancin_inferior',kp.balancin_inferior),('pierna','pierna',kp.pierna),('placa','placa',kp.placa),('base','base',kp.base)]}
P['separador_A']=Pos(A[0],A[1],0)*kp.separador(13.0,"a"); P['separador_B']=Pos(B[0],B[1],0)*kp.separador(18.5,"b")
for n,s in P.items():
    if isinstance(s,Compound) and len(s.solids())==1: s=s.solids()[0]
    from OCP.BRepBuilderAPI import BRepBuilderAPI_Transform as BT
    from OCP.TopLoc import TopLoc_Location as TL
    w=s.wrapped; tr=w.Location().Transformation(); w0=w.Located(TL()); s=Solid(BT(w0,tr,True).Shape()); s.label=n  # geometria en su pose, sin 'location'
    export_step(s,f'solidworks/step/{n}.step'); b=s.bounding_box(); print(n,b.min,b.max)
