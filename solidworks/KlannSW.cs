using System; using System.IO; using System.Collections.Generic; using System.Globalization;
using SolidWorks.Interop.sldworks; using SolidWorks.Interop.swconst;
public class KlannSW {
 static SldWorks sw; static string D;
 static void Log(string s){ Console.WriteLine(s); Console.Out.Flush(); }
 static void Conectar(){
  Type t=Type.GetTypeFromProgID("SldWorks.Application"); sw=(SldWorks)Activator.CreateInstance(t); sw.Visible=true; Log("SW "+sw.RevisionNumber());
 }
 static Face2 Cil(Component2 c,double x,double y,double r){   // cilindro de eje z en (x,y) mm
  object bi; object[] bs=(object[])c.GetBodies3((int)swBodyType_e.swSolidBody,out bi); if(bs==null) return null;
  Face2 best=null; double err=0.3;
  foreach(Body2 b in bs) foreach(Face2 f in (object[])b.GetFaces()){ Surface s=(Surface)f.GetSurface(); if(!s.IsCylinder()) continue;
   double[] p=(double[])s.CylinderParams; if(Math.Abs(p[5])<0.99) continue; if(r>0&&Math.Abs(p[6]*1000-r)>0.05) continue;
   double e=Math.Abs(p[0]*1000-x)+Math.Abs(p[1]*1000-y); if(e<err){err=e;best=f;} }
  return best; }
 static Feature Plano(Component2 c){ Feature f=(Feature)c.FirstFeature(); while(f!=null){ if(f.GetTypeName2()=="RefPlane") return f; f=(Feature)f.GetNextFeature(); } return null; }
 static Feature Plano(ModelDoc2 m){ Feature f=(Feature)m.FirstFeature(); while(f!=null){ if(f.GetTypeName2()=="RefPlane") return f; f=(Feature)f.GetNextFeature(); } return null; }
 static Component2 Comp(AssemblyDoc a,string n){ foreach(Component2 c in (object[])a.GetComponents(true)) if(c.Name2.StartsWith(n+"-")) return c; return null; }
 public static void Run(string d,string modo){ D=d; try{ Conectar(); if(modo=="armar") Armar(); else if(modo=="guardar"){ ModelDoc2 m=(ModelDoc2)sw.ActiveDoc; AssemblyDoc a=(AssemblyDoc)m; int er=0,wr=0; Feature f=(Feature)m.FirstFeature(); while(f!=null){ if(f.GetTypeName2()=="MateGroup"){ Feature g=(Feature)f.GetFirstSubFeature(); while(g!=null){ bool w; Log(g.Name+" "+g.GetTypeName2()+" err "+g.GetErrorCode2(out w)); g=(Feature)g.GetNextSubFeature(); } } f=(Feature)f.GetNextFeature(); } m.Extension.SaveAs(D+"\\modelo\\Klann.SLDASM",0,1,null,ref er,ref wr); Log("guardado "+er+" "+wr); foreach(string n in new string[]{"engranaje","pinon","biela","pierna"}) Log(n+" "+Comp(a,n).GetConstrainedStatus()); } else if(modo=="docs"){ foreach(ModelDoc2 q in (object[])(sw.GetDocuments()??new object[0])) Log(q.GetTitle()+" | "+q.GetPathName()+" | vis "+q.Visible+" | "+q.GetType()); } else if(modo=="ver") Ver(); else if(modo=="mover") Mover(); else if(modo=="cerrar"){ sw.CloseAllDocuments(true); sw.ExitApp(); }; }catch(Exception e){ Log("ERROR "+e); } }
 static void Armar(){ foreach(ModelDoc2 q in (object[])(sw.GetDocuments()??new object[0])) if(q.GetPathName().ToLower().Contains("proyectoklann")&&q.GetType()==2) sw.CloseDoc(q.GetTitle()); foreach(ModelDoc2 q in (object[])(sw.GetDocuments()??new object[0])) if(q.GetPathName().ToLower().Contains("proyectoklann")) sw.CloseDoc(q.GetTitle());
  string[] N={"placa","base","separador_A","separador_B","engranaje","pinon","biela","balancin_superior","balancin_inferior","pierna"};
  int[] col={0x404040,0x404040,0x909090,0x909090,0x1E78E6,0x32B4F0,0xE07850,0xD8A860,0xD8A860,0xC8C8C8};
  int er=0,wr=0; Directory.CreateDirectory(D+"\\modelo");
  for(int k=0;k<N.Length;k++){ string o=D+"\\modelo\\"+N[k]+".SLDPRT"; if(File.Exists(o)) continue;
   ImportStepData im=(ImportStepData)sw.GetImportFileData(D+"\\step\\"+N[k]+".step");
   ModelDoc2 m=(ModelDoc2)sw.LoadFile4(D+"\\step\\"+N[k]+".step","r",im,ref er); if(m==null){Log("no importo "+N[k]+" "+er);return;}
   double[] v={(col[k]&255)/255.0,((col[k]>>8)&255)/255.0,((col[k]>>16)&255)/255.0,0.6,0.8,0.3,0.3,0,0}; m.MaterialPropertyValues=v;
   m.Extension.SaveAs(o,0,1,null,ref er,ref wr); Log("pieza "+N[k]+" tipo "+m.GetType()); }
  ModelDoc2 am=(ModelDoc2)sw.NewDocument(@"C:\ProgramData\SOLIDWORKS\SOLIDWORKS 2021\templates\Assembly.ASMDOT",0,0,0); AssemblyDoc a=(AssemblyDoc)am; Log("asm "+(am==null?"NULO":am.GetTitle())); string ti=am.GetTitle();
  foreach(string n in N) sw.OpenDoc6(D+"\\modelo\\"+n+".SLDPRT",1,1,"",ref er,ref wr); sw.ActivateDoc3(ti,false,0,ref er);
  foreach(string n in N){ Component2 c=(Component2)a.AddComponent5(D+"\\modelo\\"+n+".SLDPRT",0,"",false,"",0,0,0); if(c==null){Log("no inserto "+n);return;}
   MathUtility mu=(MathUtility)sw.GetMathUtility(); double[] id={1,0,0,0,1,0,0,0,1,0,0,0,1,0,0,0};
   bool fijo=(n=="placa"||n=="base"||n.StartsWith("separador")); am.ClearSelection2(true); c.Select4(false,null,false); a.UnfixComponent();
   c.Transform2=(MathTransform)mu.CreateTransform(id); if(fijo){am.ClearSelection2(true);c.Select4(false,null,false);a.FixComponent();}
   am.ClearSelection2(true); Log("inserto "+c.Name2+" fijo="+c.IsFixed()); }
  am.EditRebuild3();
  foreach(string n in new string[]{"engranaje","pinon","biela","balancin_superior","balancin_inferior","pierna"})
   Mate(am,a,Plano(Comp(a,n)),Plano(am),swMateType_e.swMateCOINCIDENT,n+" plano");
  Conc(am,a,"engranaje",0,0,"placa",0,0,"O"); Conc(am,a,"pinon",28.779,-28.779,"placa",28.779,-28.779,"motor");
  Conc(am,a,"biela",-20,0,"engranaje",-20,0,"C"); Conc(am,a,"biela",-64.03,0,"balancin_inferior",-64.03,0,"E");
  Conc(am,a,"balancin_inferior",-44.03,-13.13,"separador_B",-44.03,-13.13,"B"); Conc(am,a,"biela",-102.01,8.66,"pierna",-102.01,8.66,"K");
  Conc(am,a,"pierna",-54.70,55.97,"balancin_superior",-54.70,55.97,"H"); Conc(am,a,"balancin_superior",-17.39,45.97,"separador_A",-17.39,45.97,"A");
  am.EditRebuild3(); am.Extension.SaveAs(D+"\\modelo\\Klann.SLDASM",0,1,null,ref er,ref wr); Log("guardado "+er+" "+wr);
  foreach(string n in N) Log(n+" restr="+Comp(a,n).GetConstrainedStatus());
 }
 static void Conc(ModelDoc2 m,AssemblyDoc a,string p,double x,double y,string q,double u,double v,string n){
  Face2 f=Cil(Comp(a,p),x,y,0),g=Cil(Comp(a,q),u,v,0); if(f==null||g==null){Log("FALTA cara "+n+" "+(f==null)+(g==null));return;} 
  m.ClearSelection2(true); ((Entity)f).Select4(true,null); ((Entity)g).Select4(true,null); int es=0;
  Mate2 t=(Mate2)a.AddMate5((int)swMateType_e.swMateCONCENTRIC,(int)swMateAlign_e.swMateAlignCLOSEST,false,0,0,0,1,1,0,0,0,false,false,0,out es); Log("junta "+n+" "+(t!=null)+" estado "+es); m.ClearSelection2(true); }
 static void Mate(ModelDoc2 m,AssemblyDoc a,Feature f,Feature g,swMateType_e ty,string n){ m.ClearSelection2(true); f.Select2(true,0); g.Select2(true,0); int es=0;
  Mate2 t=(Mate2)a.AddMate5((int)ty,(int)swMateAlign_e.swMateAlignALIGNED,false,0,0,0,1,1,0,0,0,false,false,0,out es); Log("mate "+n+" "+(t!=null)+" estado "+es); m.ClearSelection2(true);}
 static void Ver(){ int er=0; ModelDoc2 m=(ModelDoc2)sw.ActivateDoc3("Klann.SLDASM",false,0,ref er); AssemblyDoc a=(AssemblyDoc)m;
  foreach(string n in new string[]{"biela","pierna"}){ Component2 c=Comp(a,n); object bi; object[] bs=(object[])c.GetBodies3(0,out bi); double[] T=(double[])c.Transform2.ArrayData; Log(n+" "+T[0]+" "+T[4]+" "+T[9]+" "+T[10]+" "+T[11]);
   foreach(Body2 b in bs) foreach(Face2 f in (object[])b.GetFaces()){ Surface s=(Surface)f.GetSurface(); if(!s.IsCylinder()) continue; double[] p=(double[])s.CylinderParams; Log(string.Format("{0:F2} {1:F2} {2:F2} | {3:F2} {4:F2} {5:F2} r{6:F2}",p[0]*1000,p[1]*1000,p[2]*1000,p[3],p[4],p[5],p[6]*1000)); } } }
 static void Mover(){
  int er=0,wr=0; ModelDoc2 m=(ModelDoc2)sw.ActivateDoc3("Klann.SLDASM",false,0,ref er); if(m==null) m=(ModelDoc2)sw.OpenDoc6(D+"\\modelo\\Klann.SLDASM",2,1,"",ref er,ref wr);
  AssemblyDoc a=(AssemblyDoc)m; MathUtility mu=(MathUtility)sw.GetMathUtility(); Component2 g=Comp(a,"engranaje"),p=Comp(a,"pierna"),b=Comp(a,"biela"),h=Comp(a,"pinon");
  ModelView v=(ModelView)m.ActiveView; m.ShowNamedView2("",1); m.ViewZoomtofit2(); v.ZoomByFactor(0.80);
  string[] cn={"placa","base","separador_A","separador_B","engranaje","pinon","biela","balancin_superior","balancin_inferior","pierna"}; double[,] rg={{.35,.35,.38},{.35,.35,.38},{.6,.6,.6},{.6,.6,.6},{.95,.5,.15},{.98,.75,.2},{.3,.45,.95},{.45,.7,.95},{.45,.7,.95},{.9,.9,.9}};
  for(int k=0;k<cn.Length;k++) Comp(a,cn[k]).SetMaterialPropertyValues2(new double[]{rg[k,0],rg[k,1],rg[k,2],1,0.9,0.1,0.2,0,0},1,null); Directory.CreateDirectory(D+"\\frames");
  StreamWriter w=new StreamWriter(D+"\\pie_solidworks.csv"); w.WriteLine("theta2_deg,Fx_mm,Fy_mm,Kx_mm,Ky_mm,giro_pinon_deg"); CultureInfo ci=CultureInfo.InvariantCulture;
  for(int k=0;k<=120;k++){ double q=k*3*Math.PI/180; double[] t={Math.Cos(q),Math.Sin(q),0,-Math.Sin(q),Math.Cos(q),0,0,0,1,0,0,0,1,0,0,0};
   bool ok=g.SetTransformAndSolve2((MathTransform)mu.CreateTransform(t)); double qp=-2*q,cx=0.028779,cy=-0.028779; double[] u={Math.Cos(qp),Math.Sin(qp),0,-Math.Sin(qp),Math.Cos(qp),0,0,0,1,cx-cx*Math.Cos(qp)+cy*Math.Sin(qp),cy-cx*Math.Sin(qp)-cy*Math.Cos(qp),0,1,0,0,0};
   h.SetTransformAndSolve2((MathTransform)mu.CreateTransform(u));
   double[] F=Pt(mu,p,-119.3284,-55.9701),K=Pt(mu,p,-102.0149,8.6567); double[] T=(double[])g.Transform2.ArrayData; double th=Math.Atan2(T[1],T[0])*180/Math.PI+180; double[] H=(double[])h.Transform2.ArrayData;
   w.WriteLine(string.Format(ci,"{0:F3},{1:F4},{2:F4},{3:F4},{4:F4},{5:F2}",th,F[0],F[1],K[0],K[1],Math.Atan2(H[1],H[0])*180/Math.PI));
   if(k%20==0) Log(k+" ok="+ok+" th="+th.ToString("F2")+" F="+F[0].ToString("F2")+","+F[1].ToString("F2"));
   m.GraphicsRedraw2(); m.SaveBMP(D+"\\frames\\f"+k.ToString("D3")+".bmp",1280,960); }
  w.Close(); m.Save3(1,ref er,ref wr); }
 static double[] Pt(MathUtility mu,Component2 c,double x,double y){ MathPoint p=(MathPoint)mu.CreatePoint(new double[]{x/1000,y/1000,0}); p=(MathPoint)p.MultiplyTransform(c.Transform2); double[] r=(double[])p.ArrayData; return new double[]{r[0]*1000,r[1]*1000}; }
}
