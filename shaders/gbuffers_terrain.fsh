/*
 _______ _________ _______  _______  _
(  ____ \\__   __/(  ___  )(  ____ )( )
| (    \/   ) (   | (   ) || (    )|| |
| (_____    | |   | |   | || (____)|| |
(_____  )   | |   | |   | ||  _____)| |
      ) |   | |   | |   | || (      (_)
/\____) |   | |   | (___) || )       _
\_______)   )_(   (_______)|/       (_)

This shader is for use with the Optifine Mod. This shdaer will not work correctly when used with the GLSL Shaders Mod.
This shdaer was orignally made by MiningGodBruce, and modified by RYRY1002.

90% of the credit for this shader goes MiningGodBruce.
Make sure you give him some love.
https://www.youtube.com/user/MiningGodBruce

*/

#version 450 compatibility

#define WAVE_HEIGHT 0.15


uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
uniform sampler2D noisetex;

vec3 cameraPos;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;
uniform float far;

in mat3 tbnMatrix;

in vec4 shadowPosition;
in vec4 vertPosition;
in vec4 color;

in vec3 playerSpacePosition;
in vec3 preAcidWorldPosition;
in vec3 worldPosition;
in vec3 vertNormal;

in vec2 texcoord;
in vec2 mcLightmap;

in float materialIDs;
in float collapsedMaterialIDs;
in float fogEnabled;
in float waterMask;
in float entityID;
in float left;
in float right;
in float pre;
in float post;

in vec3 topLeft;
in vec3 topRight;
in vec3 bottomRight;
in vec3 bottomLeft;


/* DRAWBUFFERS:2103 */


vec2 textureSmooth(in vec2 coord) {
	vec2 res = vec2(64.0);

	coord *= res;
	coord += 0.5;

	vec2 whole = floor(coord);
	vec2 part  = fract(coord);

	part.x = part.x * part.x * (3.0 - 2.0 * part.x);
	part.y = part.y * part.y * (3.0 - 2.0 * part.y);

	coord = whole + part;

	coord -= 0.5;
	coord /= res;

	return coord;
}

float GetWave(in float weight, inout float weights, in vec2 coord) {
	weights += weight;
	coord = textureSmooth(coord);
	return texture2D(noisetex, coord).x * weight;
}

float GetWaves(vec3 position, in float scale) {
	float speed	= 0.9;

	vec2 p     = position.xz / 20.0;
		 p.xy -= position.y / 20.0;
		 p.x  *= -1.0;

	float waves = 0.0;
	float weights = 0.0;

	waves += GetWave(1.0, weights, p * vec2(2.0, 1.2) + vec2(0.0, p.x * 2.1));

	p /= 2.1;
	waves += GetWave(2.1, weights, p * vec2(2.0, 1.4) + vec2(0.0, -p.x * 2.1));

	p /= 1.5;
	waves += abs(GetWave(7.25, weights, p * vec2(1.0, 0.75) + vec2(0.0, p.x * 1.1)));

	p /= 1.3;
	waves += GetWave(9.25, weights, p * vec2(1.0, 0.75) + vec2(0.0, -p.x * 1.7));

	waves /= weights;

	return waves;
}

vec3 GetWavesNormal(vec3 position, in float scale, in mat3 tbnMatrix) {
	float waveHeight = WAVE_HEIGHT;

	const float sampleDistance = 3.0;

	position -= vec3(0.005, 0.0, 0.005) * sampleDistance;

	float wavesCenter = GetWaves(position, scale);
	float wavesLeft = GetWaves(position + vec3(0.01 * sampleDistance, 0.0, 0.0), scale);
	float wavesUp   = GetWaves(position + vec3(0.0, 0.0, 0.01 * sampleDistance), scale);

	vec3 wavesNormal;
		 wavesNormal.r = wavesCenter - wavesLeft;
		 wavesNormal.g = wavesCenter - wavesUp;

		 wavesNormal.r *= 30.0 * waveHeight / sampleDistance;
		 wavesNormal.g *= 30.0 * waveHeight / sampleDistance;

		 wavesNormal.b = sqrt(1.0 - wavesNormal.r * wavesNormal.r - wavesNormal.g * wavesNormal.g);
		 wavesNormal.rgb = normalize(wavesNormal.rgb);

	return wavesNormal.rgb;
}

float CollapseMaterialIDs(in float materialIDs, in float bit0, in float bit1, in float bit2, in float bit3) {
	materialIDs += 128.0 * bit0;
	materialIDs +=  64.0 * bit1;
	materialIDs +=  32.0 * bit2;
	materialIDs +=  16.0 * bit3;

	materialIDs += 0.1;
	materialIDs /= 255.0;

	return materialIDs;
}

float CalculateFogFactor(in vec3 position, in float power) {
	float fogFactor = length(position);
		  fogFactor = max(fogFactor - gl_Fog.start, 0.0);
		  fogFactor = pow(fogFactor / (far - gl_Fog.start), power);
		  fogFactor = clamp(fogFactor, 0.0, 1.0);
		  fogFactor *= fogEnabled;
		  fogFactor = clamp(fogFactor, 0.0, 1.0);

	return fogFactor;
}

float isInFrustum;

void CalculateWaterFragment(in vec4 diffuse) {
	float lum = diffuse.r + diffuse.g + diffuse.b;
		  lum /= 3.0;
		  lum = pow(lum, 1.0) * 1.0;
		  lum += 0.0;

	vec3 waterColor = normalize(color.rgb);

	diffuse = vec4(0.1, 0.7, 1.0, 210.0/255.0);
	diffuse.rgb *= 0.8 * waterColor.rgb;
	diffuse.rgb *= vec3(lum);

	vec3 normal = GetWavesNormal(preAcidWorldPosition, 1.0, tbnMatrix) * tbnMatrix * 0.5 + 0.5;
	vec3 specularity = vec3(1.0);

	gl_FragData[0] = diffuse;
	gl_FragData[1] = vec4(CollapseMaterialIDs(materialIDs, left, right, isInFrustum, 0.0), mcLightmap.r, mcLightmap.g, 1.0);
	gl_FragData[2] = vec4(normal, 1.0);
	gl_FragData[3] = vec4(specularity.r + specularity.g, specularity.b, 0.0, 1.0);
	gl_FragData[4] = vec4(shadowPosition.xyz / 528.0 + 0.5, 1.0);
}

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));

    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;

    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);

    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}


struct plane {
	vec3 p0;
	vec3 p1;
	vec3 p2;

	vec3 n;

	float dist;
};

const float gateTop		= 130.5;
const float gateBottom	= 127.5;
const float gateLeft	= -0.5;
const float gateRight	= 1.5;

float planeDistance(in vec3 point, in vec3 p0, in vec3 p1, in vec3 p2) {
	vec3 normal = normalize(cross(p1 - p0, p2 - p0));

	return normal.x * point.x + normal.y * point.y + normal.z * point.z - dot(normal, p0);
}

float frustumCheck(in float x) {		//returns true terrain inside the constructed frustum
	if (worldPosition.x < x && cameraPos.x < x)
		return 0.0;

	float topDistance		= planeDistance(playerSpacePosition.xyz, vec3(0.0), topRight,		topLeft);
	float bottomDistance	= planeDistance(playerSpacePosition.xyz, vec3(0.0), bottomRight,	bottomLeft);
	float leftDistance		= planeDistance(playerSpacePosition.xyz, vec3(0.0), topLeft,		bottomLeft);
	float rightDistance		= planeDistance(playerSpacePosition.xyz, vec3(0.0), topRight,		bottomRight);

	if (worldPosition.x > x && cameraPos.x < x) {
		if (sign(leftDistance) > -0.5
		 || sign(rightDistance) < 0.5
		 || sign(topDistance) > 0.5
		 || sign(bottomDistance) < 0.5)
			return 0.0; }
	else
		if (sign(leftDistance) > -0.5
		 && sign(rightDistance) < 0.5
		 && sign(topDistance) > 0.5
		 && sign(bottomDistance) < 0.5)
			return 0.0;

	return 1.0;
}

void doEuclid(in float x) {
	if (abs(cameraPos.x - x) > 385.0) return;

	if (frustumCheck(x) > 0.5) {
		isInFrustum = 1.0;
		if (pre > 0.5) discard;
	} else if (post > 0.5) discard;
}

void main() {
	cameraPos = cameraPosition + vec3(0.0, -130.0, 0.0);
	if (CalculateFogFactor(playerSpacePosition, 2.0) >= 0.99) discard;

	isInFrustum = 0.0;

	doEuclid(3734.5);
	doEuclid(9046.5);
	doEuclid(11000.5);
	doEuclid(14000.5);


	vec4 color2 = color;
	color2.rgb = rgb2hsv(color2.rgb);
	if ((materialIDs > 1.5 && materialIDs < 2.5) || (entityID > 1.5 && entityID < 2.5) && (color2.g > 0.0)) color2.r = 104.0 / 360.0;
	if ((materialIDs > 1.5 && materialIDs < 2.5) || (entityID > 1.5 && entityID < 2.5) && (color2.g > 0.0)) color2.g = 0.55;
	if ((materialIDs > 1.5 && materialIDs < 2.5) || (entityID > 1.5 && entityID < 2.5) && (color2.g > 0.0)) color2.b = 0.85;
	color2.rgb = hsv2rgb(color2.rgb);


	vec4 diffuse		= texture2D(texture, texcoord) * color2;
	if (waterMask > 0.5) { CalculateWaterFragment(diffuse); return; }
	vec3 normal			= vertNormal * 0.5 + 0.5;


	gl_FragData[0] = diffuse;
	gl_FragData[1] = vec4(CollapseMaterialIDs(materialIDs, left, right, isInFrustum, 0.0), mcLightmap.r, mcLightmap.g, 1.0);
	gl_FragData[2] = vec4(normal, 1.0);
	gl_FragData[3] = vec4(shadowPosition.xyz / 528.0 + 0.5, 1.0);
}