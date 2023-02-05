#define threshhold 99.
#define fThreshhold .99

P_DEFAULT float hash(P_DEFAULT float n) {
	return fract((1.0 + cos(n)) * 415.92653);
}

P_DEFAULT float noise2d(P_UV vec2 x) {
	P_DEFAULT float xhash = hash(x.x * 37.0);
	P_DEFAULT float yhash = hash(x.y * 57.0);
	return fract(xhash + yhash);
}

P_COLOR vec4 FragmentKernel (P_UV vec2 texCoord ) {
	P_UV vec2 pos = texCoord.xy;
	P_COLOR vec3 color = vec3(0.1, 0.2, 0.4) * (1. - pos.y);
	
	P_DEFAULT float starVal = noise2d(pos);
	if (starVal > fThreshhold) {
		starVal *= 99.;
		starVal = pow((starVal - threshhold), 2.0) * 0.8;
		color += vec3(starVal);
	}

	return CoronaColorScale(vec4(vec3(color),1.0));

}