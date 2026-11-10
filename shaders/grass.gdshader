shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.28,.48,.16,1.);
void vertex(){
 float w=sin(TIME*1.7+MODEL_MATRIX[3].x*.7+MODEL_MATRIX[3].z*.4);
 VERTEX.x+=w*UV.y*UV.y*.16;VERTEX.z+=cos(TIME+MODEL_MATRIX[3].x)*UV.y*.08;
}
void fragment(){ ALBEDO=tint.rgb*mix(.62,1.18,UV.y);ROUGHNESS=.95; }
