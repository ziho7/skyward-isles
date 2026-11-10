shader_type sky;
render_mode use_half_res_pass;

uniform sampler3D noise_volume : filter_linear, repeat_enable;
uniform vec3 sun_direction = vec3(-0.57,0.075,-0.82);
uniform vec3 flight_origin = vec3(0.,240.,0.);
uniform float flight_time = 0.0;
uniform float cloud_density = 0.095;
uniform vec3 light_color : source_color = vec3(1.0,0.79,0.57);
uniform vec3 shadow_color : source_color = vec3(0.48,0.62,0.78);

float n3(vec3 p){return 1.-textureLod(noise_volume,p,0.).r;}
float fbm(vec3 p){return n3(p)*.57+n3(p*2.04+vec3(.13,.3,.25))*.28+n3(p*4.1)*.15;}
float tower(vec3 p,vec3 c,vec3 radius){return 1.-length((p-c)/radius);}
float density_at(vec3 p){
 p.x+=flight_time*1.15;
 float base=clamp((105.-p.y)/180.,-.5,1.6);
 // Broken cumulus banks frame an open flight corridor.
 float left=tower(p,vec3(-245.,65.,-500.),vec3(220.,250.,330.));
 float right=tower(p,vec3(250.,55.,-760.),vec3(260.,220.,400.));
 float distant=tower(p,vec3(-130.,70.,-1500.),vec3(300.,230.,400.));
 float sunbank=tower(p,vec3(-490.,200.,-1500.),vec3(450.,280.,600.));
 float profile=max(base,max(left,max(right,max(distant,sunbank))));
 if(profile<-.2)return 0.;
 float broad=fbm(p*.0013);
 float detail=n3(p*.006+vec3(.4,.1,.3));
 float erosion=n3(p*.015);
 float shape=profile*.85+broad*.80-.57;
 shape-= (1.-detail)*.085+(1.-erosion)*.03;
 return smoothstep(0.,.045,shape)*min(1.,max(profile,0.)*2.);
}
vec3 atmosphere(vec3 rd){
 float y=max(rd.y,0.);
 vec3 horizon=vec3(.62,.77,.84);
 vec3 zenith=vec3(.17,.39,.67);
 vec3 col=mix(horizon,zenith,pow(clamp(y*2.8,0.,1.),.55));
 float toward=max(dot(rd,normalize(sun_direction)),0.);
 col+=vec3(1.,.59,.29)*pow(toward,18.)*.20;
 col+=vec3(1.,.72,.40)*pow(toward,90.)*.16;
 col+=vec3(1.,.82,.56)*pow(toward,220.)*.35;
 float sun=smoothstep(.99997,.99999,toward);
 col+=vec3(1.,.83,.58)*sun*9.;
 // High wispy cirrus, sampled on a distant horizontal layer.
 if(rd.y>.10){
  vec2 uv=rd.xz/rd.y*.14;
  float wisps=fbm(vec3(uv.x*2.8+uv.y*.7,uv.y*.7,.38));
  float mask=smoothstep(.60,.77,wisps)*smoothstep(.1,.3,rd.y)*.25;
  col=mix(col,vec3(.91,.87,.81),mask);
 }
 return col;
}
vec4 march_clouds(vec3 ro,vec3 rd){
 vec3 sun=normalize(sun_direction);
 float mu=max(dot(rd,sun),0.);
 float silver=pow(mu,16.)*.9;
 vec3 result=vec3(0.);float trans=1.;
 float distance=6.;
 for(int i=0;i<130;i++){
  float step_size=mix(6.,33.,clamp(distance/2200.,0.,1.));
  vec3 p=ro+rd*distance;
  if(p.y>530.&&rd.y>0.)break;
  float d=density_at(p);
  if(d>.005){
   float optical=0.;float light_step=5.;
   for(int j=0;j<4;j++){
    optical+=density_at(p+sun*light_step)*light_step*.018;
    light_step*=2.7;
   }
   float sunlight=exp(-optical);
   float powder=1.-exp(-d*step_size*.12);
   float height_light=smoothstep(-100.,180.,p.y);
   vec3 ambient=mix(shadow_color*.19,shadow_color*.44,height_light);
   vec3 illumination=ambient+light_color*(sunlight*(.72+silver)+pow(sunlight,.35)*.20)*(.8+powder*.2);
   illumination*=.84+fbm(p*.005)*.32;
   float fog_amount=1.-exp(-distance*.00018);
   illumination=mix(illumination,vec3(.64,.76,.83),fog_amount*.4);
   float alpha=1.-exp(-d*step_size*cloud_density);
   result+=trans*alpha*illumination;
   trans*=1.-alpha;
   if(trans<.009)break;
  }
  distance+=step_size;
 }
 return vec4(result,1.-trans);
}
void sky(){
 if(AT_CUBEMAP_PASS){
  COLOR=atmosphere(EYEDIR);
 }else if(AT_HALF_RES_PASS){
  vec4 cloud=march_clouds(flight_origin,EYEDIR);
  COLOR=cloud.rgb;ALPHA=cloud.a;
 }else{
  vec3 sky_col=atmosphere(EYEDIR);
  COLOR=sky_col*(1.-HALF_RES_COLOR.a)+HALF_RES_COLOR.rgb;
 }
}
