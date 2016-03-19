attribute vec3 inVertexPosition;
attribute vec3 inVertexNormal;
attribute vec4 inVertexColor;
attribute vec2 inTexCoord0;
attribute vec2 inTexCoord1;

uniform mat4 mModelView;
uniform mat4 mWorldViewProj;
uniform mat4 mInvWorld;
uniform mat4 mTransWorld;
uniform mat4 mWorld;

uniform float dayNightRatio;
uniform vec3 eyePosition;
uniform float animationTimer;

varying vec3 vPosition;
varying vec3 worldPosition;

varying vec3 eyeVec;
varying vec3 lightVec;
varying vec3 tsEyeVec;
varying vec3 tsLightVec;

varying vec2 varTexCoord0;
varying vec4 varVertexColor;

const float e = 2.718281828459;
const float BS = 10.0;

float smoothCurve( float x ) {
  return x * x *( 3.0 - 2.0 * x );
}
float triangleWave( float x ) {
  return abs( fract( x + 0.5 ) * 2.0 - 1.0 );
}
float smoothTriangleWave( float x ) {
  return smoothCurve( triangleWave( x ) ) * 2.0 - 1.0;
}

void main(void)
{
	varTexCoord0 = inTexCoord0;
	
#if (MATERIAL_TYPE == TILE_MATERIAL_LIQUID_TRANSPARENT || MATERIAL_TYPE == TILE_MATERIAL_LIQUID_OPAQUE) && ENABLE_WAVING_WATER
	vec4 pos = vec4(inVertexPosition, 1.0);
	pos.y -= 2.0;
	pos.y -= sin (pos.z/WATER_WAVE_LENGTH + animationTimer * WATER_WAVE_SPEED * WATER_WAVE_LENGTH) * WATER_WAVE_HEIGHT
		+ sin ((pos.z/WATER_WAVE_LENGTH + animationTimer * WATER_WAVE_SPEED * WATER_WAVE_LENGTH) / 7.0) * WATER_WAVE_HEIGHT;
	gl_Position = mWorldViewProj * pos;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_LEAVES && ENABLE_WAVING_LEAVES
	vec4 pos = vec4(inVertexPosition, 1.0);
	vec4 pos2 = mWorld * vec4(inVertexPosition, 1.0);
	pos.x += (smoothTriangleWave(animationTimer*10.0 + pos2.x * 0.01 + pos2.z * 0.01) * 2.0 - 1.0) * 0.4;
	pos.y += (smoothTriangleWave(animationTimer*15.0 + pos2.x * -0.01 + pos2.z * -0.01) * 2.0 - 1.0) * 0.2;
	pos.z += (smoothTriangleWave(animationTimer*10.0 + pos2.x * -0.01 + pos2.z * -0.01) * 2.0 - 1.0) * 0.4;
	gl_Position = mWorldViewProj * pos;
#elif MATERIAL_TYPE == TILE_MATERIAL_WAVING_PLANTS && ENABLE_WAVING_PLANTS
	vec4 pos = vec4(inVertexPosition, 1.0);
	vec4 pos2 = mWorld * vec4(inVertexPosition, 1.0);
	if (inTexCoord0.y < 0.05) {
	pos.x += (smoothTriangleWave(animationTimer * 20.0 + pos2.x * 0.1 + pos2.z * 0.1) * 2.0 - 1.0) * 0.8;
			pos.y -= (smoothTriangleWave(animationTimer * 10.0 + pos2.x * -0.5 + pos2.z * -0.5) * 2.0 - 1.0) * 0.4;
	}
	gl_Position = mWorldViewProj * pos;
#else
	gl_Position = mWorldViewProj * vec4(inVertexPosition, 1.0);
#endif

	vPosition = gl_Position.xyz;
	worldPosition = (mWorld * vec4(inVertexPosition, 1.0)).xyz;
	vec3 sunPosition = vec3 (0.0, eyePosition.y * BS + 900.0, 0.0);

	vec3 normal, tangent, binormal;
	normal = normalize(inVertexNormal);
	
	if (inVertexNormal.x > 0.5) {
		//  1.0,  0.0,  0.0
		
		tangent  = normalize(vec3( 0.0,  0.0, -1.0));
		binormal = normalize(vec3( 0.0, -1.0,  0.0));
	} else if (inVertexNormal.x < -0.5) {
		// -1.0,  0.0,  0.0
		
		tangent  = normalize(vec3( 0.0,  0.0,  1.0));
		binormal = normalize(vec3( 0.0, -1.0,  0.0));
	} else if (inVertexNormal.y > 0.5) {
		//  0.0,  1.0,  0.0
		
		tangent  = normalize(vec3( 1.0,  0.0,  0.0));
		binormal = normalize(vec3( 0.0,  0.0,  1.0));
	} else if (inVertexNormal.y < -0.5) {
		//  0.0, -1.0,  0.0
		
		tangent  = normalize(vec3( 1.0,  0.0,  0.0));
		binormal = normalize(vec3( 0.0,  0.0,  1.0));
	} else if (inVertexNormal.z > 0.5) {
		//  0.0,  0.0,  1.0
		
		tangent  = normalize( vec3( 1.0,  0.0,  0.0));
		binormal = normalize( vec3( 0.0, -1.0,  0.0));
	} else if (inVertexNormal.z < -0.5) {
		//  0.0,  0.0, -1.0
		
		tangent  = normalize(vec3(-1.0,  0.0,  0.0));
		binormal = normalize(vec3( 0.0, -1.0,  0.0));
	}
	mat3 tbnMatrix = mat3(	tangent.x, binormal.x, normal.x,
							tangent.y, binormal.y, normal.y,
							tangent.z, binormal.z, normal.z);

	lightVec = sunPosition - worldPosition;
	tsLightVec = lightVec * tbnMatrix;
	eyeVec = (mModelView * vec4(inVertexPosition, 1.0)).xyz;
	tsEyeVec = eyeVec * tbnMatrix;

	vec4 color;
	float day = inVertexColor.b;
	float night = inVertexColor.g;
	float light_source = inVertexColor.r;

	float rg = mix(night, day, dayNightRatio);
	rg += light_source * 2.5;
	float b = rg;

	b += (day - night) / 13.0;
	rg -= (day - night) / 13.0;

	b += max(0.0, (1.0 - abs(b - 0.13)/0.17) * 0.025);
	rg += max(0.0, (1.0 - abs(rg - 0.85)/0.15) * 0.065);

	color.r = rg;
	color.g = rg;
	color.b = b;

	color.a = inVertexColor.a;
	varVertexColor = clamp(color,0.0,1.0);
}
