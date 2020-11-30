/*
 _______ 	_________ 	_______ 	 _______ 	 _
/  ____ \	\__   __/	/  ___  \	/  ____ \	| |
| (    \/	   | |   	| |   | |	| |    ||	| |
| (_____ 	   | |   	| |   | |	| |____||	| |
\_____  \	   | |   	| |   | |	|  _____)	| |
      | |	   | |   	| |   | |	| |      	|_|
/\____| |	   | |   	| |___| |	| |      	 _
\_______/	   |_|   	\_______/	|/       	(_)

If you are expecting to use this shader as a normal shader, don't.
It has terrible performance and does not have playablilty in mind at all.
I mean, you can, but good luck.

This shader is for use with the Optifine Mod. This shader will not work correctly when used with the GLSL Shaders Mod.
This shader was orignally made by MiningGodBruce, and modified by RYRY1002.

Most of the work done for this shader was done by MiningGodBruce.
Make sure you give him some love.
https://www.youtube.com/user/MiningGodBruce

And maybe give me some love also.
(Thanks!)
https://links.riley.technology/

You are free to modify this shader for personal uses however you like! (Do not sell this shader for currency in any way)
I am not responsible if this shader breaks because you modify it.
Use at your own risk.

*/

#version 450 compatibility

#define CUSTOM_TIME_CYCLE

#define VERTEX_SCALE 0.5

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;

uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 upPosition;
uniform vec3 cameraPosition;
#define track cameraPosition.x
uniform vec3 previousCameraPosition;

uniform float frameTimeCounter;
uniform float rainStrength;
uniform float sunAngle;
uniform float far;

out vec3 lightVector;
out vec3 colorSunlight;
out vec3 colorSkylight;
out vec3 colorSunglow;
out vec3 colorBouncedSunlight;
out vec3 colorScatteredSunlight;
out vec3 colorTorchlight;
out vec3 colorWaterMurk;
out vec3 colorWaterBlue;
out vec3 colorSkyTint;

out vec2 texcoord;

out float timeNoon;
out float timeMidnight;
out float timeSunriseSunset;
out float horizonTime;
out float timeSun;
out float timeMoon;
out float fogEnabled;

out mat4 shadowView;
out mat4 shadowViewInverse;

out float timeCycle;
out float timeAngle;
out float pathRotationAngle;
out float twistAngle;

const float rayleigh = 0.02;
const float sunPathRotation = -40.0;
#define PI 3.14159265
const float rad = 0.01745329;


float clamp01(in float x) {
	return clamp(x, 0.0, 1.0); }

float clamp01(in float x, in float start, in float length) {
	return clamp((clamp(x, start, start + length) - start) / length, 0.0, 1.0); }

float clamp10(in float x) {
	return 1.0 - clamp(x, 0.0, 1.0); }

float clamp10(in float x, in float start, in float length) {
	return 1.0 - clamp((clamp(x, start, start + length) - start) / length, 0.0, 1.0); }

//These functions are for a linear domain of 0.0-1.0 & have a range of 0.0-1.0
float powslow(in float x, in float power) {	//linear --> exponentially slow
	return pow(x, power); }

float powfast(in float x, in float power) {	//linear --> exponentially fast
	return 1.0 - pow(1.0 - x, power); }

//sinpow functions are just like power functions, but use a mix of exponential and trigonometric interpolation
float sinpowslow(in float x, in float power) {
	return 1.0 - pow(sin(pow(1.0 - x, 1.0 / power) * PI / 2.0), power); }

float sinpowfast(in float x, in float power) {
	return pow(sin(pow(x, 1.0 / power) * PI / 2.0), power); }

float sinpowsharp(in float x, in float power) {
	return sinpowfast(clamp01(x * 2.0), power) * 0.5 + sinpowslow(clamp01(x * 2.0 - 1.0), power) * 0.5; }

float sinpowsmooth(in float x, in float power) {
	return sinpowslow(clamp01(x * 2.0), power) * 0.5 + sinpowfast(clamp01(x * 2.0 - 1.0), power) * 0.5; }

//cubesmooth functions have zero slopes at the start & end of their ranges
float cubesmooth(in float x) {
	return x * x * (3.0 - 2.0 * x); }

float cubesmoothslow(in float x, in float power) {
	return pow(x, power - 1.0) * (power - (power - 1.0) * x); }

float cubesmoothfast(in float x, in float power) {
	return 1.0 - pow(1.0 - x, power - 1.0) * (power - (power - 1.0) * (1.0 - x)); }


//U functions take a linear domain 0.0-1.0 and have a range that goes from 0.0 to 1.0 and back to 0.0
float sinpowsharpU(in float x, in float power) {
	return sinpowfast(clamp01(x * 2.0), power) - sinpowslow(clamp01(x * 2.0 - 1.0), power); }

float sinpowfastU(in float x, in float power) {
	//return cubesmooth(clamp01(x * 2.0 - 1.0)); }
	return sinpowfast(clamp01(x * power), power) - cubesmooth(clamp01(max(x * power * 2.0 - 1.0, 0.0) / power)); }

float CubicSmooth(in float x) {
	return x * x * (3.0 - 2.0 * x);
}

void rotate(inout vec2 vector, float degrees) {
	degrees *= 0.0174533;		//Convert from degrees to radians

	vector *= mat2(cos(degrees), -sin(degrees),
				   sin(degrees),  cos(degrees));
}

float CalculateShadowView() {
	timeAngle = sunAngle * 360.0;
	pathRotationAngle = sunPathRotation;
	twistAngle = 0.0;


	timeAngle = 50.0;
	// These manage the Custom Cycle
	timeAngle += -50.0 * sinpowsmooth(clamp01(previousCameraPosition.x, 3734.0, 4034.0 - 3734.0), 1.0);
	timeAngle += 85.0 * sinpowsmooth(clamp01(previousCameraPosition.x, 7500.0, 3682.0 - 0.0), 1.0);


	timeCycle = timeAngle;

	float isNight = abs(sign(float(mod(timeAngle, 360.0) > 180.0) - float(mod(abs(pathRotationAngle) + 90.0, 360.0) > 180.0))); // When they're not both above or below the horizon

	timeAngle = -mod(timeAngle, 180.0) * rad;
	pathRotationAngle = (mod(pathRotationAngle + 90.0, 180.0) - 90.0) * rad;
	twistAngle *= rad;


	float A = cos(pathRotationAngle);
	float B = sin(pathRotationAngle);
	float C = cos(timeAngle);
	float D = sin(timeAngle);
	float E = cos(twistAngle);
	float F = sin(twistAngle);

	shadowView = mat4(
	-D*E + B*C*F,  -A*F,  C*E + B*D*F, shadowModelView[0].w,
	        -A*C,    -B,         -A*D, shadowModelView[1].w,
	 B*C*E + D*F,  -A*E,  B*D*E - C*F, shadowModelView[2].w,
	 shadowModelView[3]);

	shadowViewInverse = mat4(
	-E*D + F*B*C,  -C*A,  F*D + E*B*C,  0.0,
	        -F*A,    -B,         -E*A,  0.0,
	 F*B*D + E*C,  -A*D,  E*B*D - F*C,  0.0,
	         0.0,   0.0,          0.0,  1.0);

	return isNight;
}

void main() {
	CalculateShadowView();

	texcoord    = gl_MultiTexCoord0.st;
	gl_Position = ftransform();

	gl_Position.xy = ((gl_Position.xy * 0.5 + 0.5) * VERTEX_SCALE) * 2.0 - 1.0;


	float isNight = CalculateShadowView();

	lightVector = normalize((gbufferModelView * shadowViewInverse * vec4(0.0, 0.0, 1.0, 0.0)).xyz);

	vec3 sunVector = lightVector ;// * (1.0 - isNight * 2.0);

	float LdotUp = dot(normalize(upPosition), sunVector);
	float LdotDown = -LdotUp;

	float timePow		= 4.0;

	horizonTime			= CubicSmooth(clamp01((1.0 - abs(LdotUp)) * 4.0 - 3.0));

	timeNoon			= 1.0 - pow(1.0 - clamp01(LdotUp), timePow);
	timeMidnight		= 1.0 - pow(1.0 - clamp01(LdotDown), timePow);
	timeMidnight		= 1.0 - pow(1.0 - timeMidnight, 2.0);

	timeSunriseSunset	= 1.0 - timeNoon;
	timeSunriseSunset	*= 1.0 - timeMidnight;
	timeSun				= float(timeNoon > 0.0);
	timeMoon			= float(timeMidnight > 0.0);


	colorWaterMurk = vec3(0.2, 0.5, 0.95);
	colorWaterBlue = vec3(0.2, 0.5, 0.95);
	colorWaterBlue = mix(colorWaterBlue, vec3(1.0), vec3(0.5));


	//colors for shadows/sunlight and sky
	vec3 sunrise_sun;
	sunrise_sun.r = 1.00;
	sunrise_sun.g = 0.58;
	sunrise_sun.b = 0.00;
	sunrise_sun *= 0.65 * 0.5 * timeSun;

	vec3 sunrise_amb;
	sunrise_amb.r = 0.30;
	sunrise_amb.g = 0.595;
	sunrise_amb.b = 0.70;


	vec3 noon_sun;
	noon_sun.r = mix(1.00, 1.00, rayleigh);
	noon_sun.g = mix(1.00, 0.75, rayleigh);
	noon_sun.b = mix(1.00, 0.00, rayleigh);

	vec3 noon_amb;
	noon_amb.r = 0.0 ;
	noon_amb.g = 0.3  ;
	noon_amb.b = 0.999;


	vec3 midnight_sun;
	midnight_sun.r = 0.3;
	midnight_sun.g = 0.3;
	midnight_sun.b = 0.3;

	vec3 midnight_amb;
	midnight_amb.r = 0.0 ;
	midnight_amb.g = 0.23;
	midnight_amb.b = 0.99;


	colorSunlight = sunrise_sun * timeSunriseSunset  +  noon_sun * timeNoon  +  midnight_sun * timeMidnight;


	sunrise_amb  = vec3(0.19, 0.35, 0.7) * 0.15 * 2.0;
	noon_amb	 = vec3(0.15, 0.29, 0.99);
	midnight_amb = vec3(0.005, 0.01, 0.02) * 0.025;

	colorSkylight = sunrise_amb * timeSunriseSunset  +  noon_amb * timeNoon  +  midnight_amb * timeMidnight;


	vec3 colorSunglow_sunrise;
	colorSunglow_sunrise.r = 1.00 * timeSunriseSunset;
	colorSunglow_sunrise.g = 0.46 * timeSunriseSunset;
	colorSunglow_sunrise.b = 0.00 * timeSunriseSunset;

	vec3 colorSunglow_noon;
	colorSunglow_noon.r = 1.0 * timeNoon;
	colorSunglow_noon.g = 1.0 * timeNoon;
	colorSunglow_noon.b = 1.0 * timeNoon;

	vec3 colorSunglow_midnight;
	colorSunglow_midnight.r = 0.05 * 0.8 * 0.0055 * timeMidnight;
	colorSunglow_midnight.g = 0.20 * 0.8 * 0.0055 * timeMidnight;
	colorSunglow_midnight.b = 0.90 * 0.8 * 0.0055 * timeMidnight;

	colorSunglow = colorSunglow_sunrise + colorSunglow_noon + colorSunglow_midnight;

	vec3 colorSkylight_rain = vec3(2.0, 2.0, 2.38) * 0.25 * (1.0 - timeMidnight * 0.995); //rain
	colorSkylight = mix(colorSkylight, colorSkylight_rain, rainStrength); //rain


	//Saturate sunlight colors
	colorSunlight = pow(colorSunlight, vec3(4.2));

	colorSunlight *= 1.0 - horizonTime;


	colorBouncedSunlight = mix(colorSunlight, colorSkylight, 0.15);

	colorScatteredSunlight = mix(colorSunlight, colorSkylight, 0.15);

	colorSunglow = pow(colorSunglow, vec3(2.5));


	//Make reflected light darker when not day time
	colorBouncedSunlight = mix(colorBouncedSunlight, colorBouncedSunlight * 0.5, timeSunriseSunset);
	colorBouncedSunlight = mix(colorBouncedSunlight, colorBouncedSunlight * 1.0, timeNoon);
	colorBouncedSunlight = mix(colorBouncedSunlight, colorBouncedSunlight * 0.000015, timeMidnight);

	//Make scattered light darker when not day time
	colorScatteredSunlight = mix(colorScatteredSunlight, colorScatteredSunlight * 0.5, timeSunriseSunset);
	colorScatteredSunlight = mix(colorScatteredSunlight, colorScatteredSunlight * 1.0, timeNoon);
	colorScatteredSunlight = mix(colorScatteredSunlight, colorScatteredSunlight * 0.000015, timeMidnight);


	float colorSunlightLum = colorSunlight.r + colorSunlight.g + colorSunlight.b;
		  colorSunlightLum /= 3.0;

	colorSunlight = mix(colorSunlight, vec3(colorSunlightLum), vec3(rainStrength));


	//Torchlight color
	float torchWhiteBalance = 0.05;
	colorTorchlight = vec3(1.00, 0.22, 0.00);
	colorTorchlight = mix(colorTorchlight, vec3(1.0), vec3(torchWhiteBalance));
	colorTorchlight = pow(colorTorchlight, vec3(0.99));

	fogEnabled = float(gl_Fog.start / far < 0.65);
}